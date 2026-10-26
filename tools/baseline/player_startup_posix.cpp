// POSIX (Linux and macOS) implementation of player_startup.hpp; player_startup.cpp is the Windows one.
// The profile folder is opened without following its final link, locked with
// flock and, on Linux, reached through /proc/self/fd for the process lifetime, so a renamed
// or replaced root is never followed. macOS has no path for a held directory descriptor: there
// the folder is reached through its path at open time, checked to be the held inode, and a
// rename of the root while the game runs is not detected. flock binds only cooperating
// processes; every copy also refuses a source whose identity, size or times change.
#include "player_startup.hpp"
#include "player_version.hpp"
#include <algorithm>
#include <atomic>
#include <cerrno>
#include <climits>
#include <cstdio>
#include <cstdlib>
#include <initializer_list>
#include <mutex>
#include <string_view>
#include <system_error>
#include <dirent.h>
#include <fcntl.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <unistd.h>
#ifdef __APPLE__
#include <pthread.h>
#endif
#include "SDL.h"
#include <nfd.h>
#ifndef __APPLE__
#ifndef RENAME_NOREPLACE
#define RENAME_NOREPLACE (1u << 0)
#endif
#endif

namespace fs = std::filesystem;

namespace baseline::player {
namespace {
// Header names stay the single source; ASCII is enforced at compile time.
template <std::size_t N>
struct Ascii {
    char text[N]{};
    consteval Ascii(const wchar_t (&wide)[N]) {
        for (std::size_t i = 0; i < N; ++i) {
            if (wide[i] < 0 || wide[i] > 0x7f) throw "profile names must be ASCII";
            text[i] = char(wide[i]);
        }
    }
    const char* c_str() const noexcept { return text; }
};
constexpr Ascii marker_file{marker_name};
constexpr Ascii save_file{save_name};
constexpr Ascii record_file{import_record_name};
constexpr char product_folder[] = "BanjoTooieScurvyDogPort";
constexpr char previous_folder[] = "BanjoTooieEncore"; // Alpha 4 default name; only ever read.
// The earlier frontend's Linux profile, $HOME/.config/BanjoTooieRecompiled (src/profile_location.cpp).
constexpr char legacy_folder[] = "BanjoTooieRecompiled";
constexpr char title[] = "Banjo-Tooie: Scurvy Dog Port";
// The runtime's stored ROM, <profile>/<game_id>.z64; the largest file a migration copies.
constexpr char rom_name[] = "bt.n64.us.1.0.z64";
constexpr off_t copy_limit = off_t(64) << 20;
constexpr std::string_view marker_bytes{marker_text, sizeof(marker_text) - 1};
fs::path log_file;
std::atomic<bool> log_only_errors{false};
struct NoAnswer {}; // The consent dialog closed or could not open; nothing is recorded.

[[noreturn]] void fail(const std::string& text) { throw Failure(text); }
std::string os_error(int error) { return " (" + std::error_code(error, std::generic_category()).message() + ")"; }
std::string in_use(const fs::path& root) {
    return "Another copy of Banjo-Tooie: Scurvy Dog Port is already using " + utf8(root) +
        ". Close it, then start the game again.";
}
#ifdef __APPLE__
bool on_main_thread() { return ::pthread_main_np() != 0; }
#else
bool on_main_thread() { return ::syscall(SYS_gettid) == ::getpid(); }
#endif

// Renames without replacing an existing entry: 0, or -1 with errno (EEXIST when the name exists).
int rename_no_replace(int from_folder, const char* from, int to_folder, const char* to) {
#ifdef __APPLE__
    return ::renameatx_np(from_folder, from, to_folder, to, RENAME_EXCL);
#else
    return int(::syscall(SYS_renameat2, from_folder, from, to_folder, to, RENAME_NOREPLACE));
#endif
}

struct Fd {
    int value = -1;
    Fd() = default;
    explicit Fd(int fd) : value(fd) {}
    Fd(Fd&& other) noexcept : value(std::exchange(other.value, -1)) {}
    Fd& operator=(Fd&& other) noexcept {
        if (this != &other) { reset(); value = std::exchange(other.value, -1); }
        return *this;
    }
    Fd(const Fd&) = delete;
    Fd& operator=(const Fd&) = delete;
    ~Fd() { reset(); }
    void reset() { if (value >= 0) ::close(value); value = -1; }
    int release() { return std::exchange(value, -1); }
    explicit operator bool() const { return value >= 0; }
};

// Held profile folders: public root, anchored storage and descriptor.
struct Held { int fd; fs::path root, storage; };
std::mutex held_mutex;
std::vector<Held> held;

bool same_inode(const struct stat& a, const struct stat& b) { return a.st_dev == b.st_dev && a.st_ino == b.st_ino; }
#ifdef __APPLE__
const timespec& mtime_of(const struct stat& s) { return s.st_mtimespec; }
const timespec& ctime_of(const struct stat& s) { return s.st_ctimespec; }
#else
const timespec& mtime_of(const struct stat& s) { return s.st_mtim; }
const timespec& ctime_of(const struct stat& s) { return s.st_ctim; }
#endif
bool unchanged(const struct stat& a, const struct stat& b) {
    return same_inode(a, b) && a.st_size == b.st_size &&
        mtime_of(a).tv_sec == mtime_of(b).tv_sec && mtime_of(a).tv_nsec == mtime_of(b).tv_nsec &&
        ctime_of(a).tv_sec == ctime_of(b).tv_sec && ctime_of(a).tv_nsec == ctime_of(b).tv_nsec;
}

fs::path normal(const fs::path& path) {
    const auto result = fs::absolute(path).lexically_normal();
    return result.has_filename() ? result : result.parent_path();
}
std::pair<fs::path, std::string> place(const fs::path& path) {
    const auto full = normal(path);
    const auto name = full.filename().native();
    if (name.empty() || name == "." || name == ".." || full.parent_path() == full)
        fail("The location " + utf8(full) + " cannot be used.");
    return {full.parent_path(), name};
}

// Exactly size bytes, then end of file.
bool read_exact(int fd, char* data, std::size_t size) {
    for (std::size_t total = 0; total < size;) {
        const ssize_t bytes = ::read(fd, data + total, size - total);
        if (bytes < 0 && errno == EINTR) continue;
        if (bytes <= 0) return false;
        total += std::size_t(bytes);
    }
    for (char extra = 0;;) {
        const ssize_t bytes = ::read(fd, &extra, 1);
        if (bytes < 0 && errno == EINTR) continue;
        return bytes == 0;
    }
}
bool write_all(int fd, const char* data, std::size_t size) {
    for (std::size_t total = 0; total < size;) {
        const ssize_t bytes = ::write(fd, data + total, size - total);
        if (bytes < 0 && errno == EINTR) continue;
        if (bytes <= 0) return false;
        total += std::size_t(bytes);
    }
    return true;
}
bool pread_equals(int fd, std::string_view expected) {
    std::string actual(expected.size() + 1, '\0');
    std::size_t total = 0;
    while (total < actual.size()) {
        const ssize_t bytes = ::pread(fd, actual.data() + total, actual.size() - total, off_t(total));
        if (bytes < 0 && errno == EINTR) continue;
        if (bytes < 0) return false;
        if (bytes == 0) break;
        total += std::size_t(bytes);
    }
    return total == expected.size() && std::string_view(actual.data(), total) == expected;
}

// Entries other than . and ..; links are listed, never followed.
bool directory_empty(int folder, const fs::path& shown) {
    const int fd = ::openat(folder, ".", O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (fd < 0) { const int error = errno; fail("The folder " + utf8(shown) + " could not be read" + os_error(error) + "."); }
    DIR* listing = ::fdopendir(fd);
    if (!listing) { const int error = errno; ::close(fd); fail("The folder " + utf8(shown) + " could not be read" + os_error(error) + "."); }
    bool empty = true;
    errno = 0;
    while (const dirent* entry = ::readdir(listing)) {
        const std::string_view name(entry->d_name);
        if (name != "." && name != "..") { empty = false; break; }
    }
    const int error = errno;
    ::closedir(listing);
    if (empty && error) fail("The folder " + utf8(shown) + " could not be read" + os_error(error) + ".");
    return empty;
}

// Opens an ordinary file entry without following a link or opening a device or
// FIFO; the descriptor must be the very file that was examined.
enum class Entry { Missing, NotOrdinary, Opened, Error };
Entry open_regular(int folder, const char* name, Fd& out, struct stat& opened, int& error) {
    struct stat named{};
    if (::fstatat(folder, name, &named, AT_SYMLINK_NOFOLLOW)) {
        error = errno;
        return error == ENOENT ? Entry::Missing : Entry::Error;
    }
    if (!S_ISREG(named.st_mode)) return Entry::NotOrdinary;
    Fd file(::openat(folder, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC));
    if (!file) {
        error = errno;
        return error == ENOENT ? Entry::Missing : error == ELOOP ? Entry::NotOrdinary : Entry::Error;
    }
    if (::fstat(file.value, &opened)) { error = errno; return Entry::Error; }
    if (!S_ISREG(opened.st_mode) || !same_inode(named, opened)) return Entry::NotOrdinary;
    out = std::move(file);
    return Entry::Opened;
}

enum class Marker { Absent, Matches, Different };
Marker read_marker(int folder, const fs::path& root) {
    Fd file;
    struct stat st{};
    int error = 0;
    switch (open_regular(folder, marker_file.c_str(), file, st, error)) {
    case Entry::Missing: return Marker::Absent;
    case Entry::NotOrdinary: return Marker::Different; // A link, folder or device is never a marker.
    case Entry::Error:
        fail("The profile marker in " + utf8(root) + " could not be opened" + os_error(error) + ". Nothing was changed.");
    case Entry::Opened: break;
    }
    if (st.st_size != off_t(marker_bytes.size())) return Marker::Different;
    std::string text(marker_bytes.size(), '\0');
    if (!read_exact(file.value, text.data(), text.size()))
        fail("The profile marker in " + utf8(root) + " could not be read. Nothing was changed.");
    return text == marker_bytes ? Marker::Matches : Marker::Different;
}

// Whole bounded file; refused if it changes while read or its name no longer
// names it. Absent: nullopt. The source is only read.
std::optional<std::string> read_ordinary(int folder, const char* name, const fs::path& shown) {
    Fd file;
    struct stat before{};
    int error = 0;
    switch (open_regular(folder, name, file, before, error)) {
    case Entry::Missing: return std::nullopt;
    case Entry::NotOrdinary: fail(utf8(shown) + " is not an ordinary file");
    case Entry::Error: fail(utf8(shown) + " could not be opened" + os_error(error));
    case Entry::Opened: break;
    }
    if (before.st_size > copy_limit) fail(utf8(shown) + " is unexpectedly large");
    std::string bytes(std::size_t(before.st_size), '\0');
    if (!read_exact(file.value, bytes.data(), bytes.size())) fail(utf8(shown) + " could not be read completely");
    struct stat after{}, named{};
    if (::fstat(file.value, &after) || !unchanged(before, after) ||
        ::fstatat(folder, name, &named, AT_SYMLINK_NOFOLLOW) || !unchanged(before, named))
        fail(utf8(shown) + " changed while it was being copied");
    return bytes;
}

// Publishes exactly bytes as name in folder, never replacing an entry. The bytes
// are written, flushed and read back in a private stage: an unnamed O_TMPFILE
// inode or, where a filesystem lacks it, a create-new named file a failure keeps,
// unused. The name is checked to be the staged inode; the folder is flushed.
// False: the name already exists.
struct Stage { int folder; std::string prefix; };
bool publish_new(int folder, const std::string& name, std::string_view bytes, const Stage& stage) {
    Fd file;
#ifdef O_TMPFILE
    file = Fd(::openat(stage.folder, ".", O_TMPFILE | O_RDWR | O_CLOEXEC, 0600));
#else
    errno = EOPNOTSUPP;  // no unnamed files here: stage a named one
#endif
    std::string stage_name;
    if (!file) {
        const int error = errno;
        if (error != EOPNOTSUPP && error != EISDIR && error != EINVAL) fail(name + " could not be staged" + os_error(error));
        for (unsigned attempt = 1;; ++attempt) {
            stage_name = stage.prefix + "-" + std::to_string(::getpid()) + "-" + std::to_string(attempt);
            file = Fd(::openat(stage.folder, stage_name.c_str(), O_CREAT | O_EXCL | O_RDWR | O_NOFOLLOW | O_CLOEXEC, 0600));
            if (file) break;
            const int create_error = errno;
            if (create_error != EEXIST || attempt == 100) fail(name + " could not be staged" + os_error(create_error));
        }
    }
    const auto kept = stage_name.empty() ? std::string() : "; its unused partial copy " + stage_name + " was kept";
    struct stat staged{};
    if (!write_all(file.value, bytes.data(), bytes.size()) || ::fsync(file.value) ||
        !pread_equals(file.value, bytes) || ::fstat(file.value, &staged))
        fail(name + " could not be written and verified" + kept);
    if (stage_name.empty()) {
#ifdef O_TMPFILE
        const auto proc = "/proc/self/fd/" + std::to_string(file.value);
        if (::linkat(AT_FDCWD, proc.c_str(), folder, name.c_str(), AT_SYMLINK_FOLLOW)) {
            const int error = errno;
            if (error == EEXIST) return false;
            fail(name + " could not be published" + os_error(error));
        }
#endif
    } else if (rename_no_replace(stage.folder, stage_name.c_str(), folder, name.c_str())) {
        const int error = errno;
        if (error == EEXIST) {
            std::fprintf(stderr, "player kept the existing %s%s\n", name.c_str(), kept.c_str());
            return false;
        }
        fail(name + " could not be published" + os_error(error) + kept);
    }
    struct stat published{};
    if (::fstatat(folder, name.c_str(), &published, AT_SYMLINK_NOFOLLOW) || !same_inode(published, staged))
        fail(name + " was replaced while it was being published");
    if (::fsync(folder) || (!stage_name.empty() && stage.folder != folder && ::fsync(stage.folder)))
        fail(name + " could not be flushed to disk");
    return true;
}
bool publish_new(int folder, const std::string& name, std::string_view bytes) {
    return publish_new(folder, name, bytes, {folder, name + ".partial"});
}

// Profile work uses the held folder whenever a path names it, publicly or through
// its anchor; another folder is opened without following its final link.
Fd open_root(const fs::path& root, fs::path& shown) {
    const auto path = normal(root);
    {
        std::lock_guard lock(held_mutex);
        for (const auto& entry : held) {
            if (path != entry.root && path != entry.storage) continue;
            shown = entry.root;
            Fd copy(::fcntl(entry.fd, F_DUPFD_CLOEXEC, 0));
            if (!copy) { const int error = errno; fail("The profile folder " + utf8(entry.root) + " could not be reopened" + os_error(error) + "."); }
            return copy;
        }
    }
    shown = path;
    if (path.native().rfind("/proc/", 0) == 0) fail("The profile path " + utf8(path) + " is not a folder this copy holds.");
    const auto [parent_path, name] = place(path);
    Fd parent(::open(parent_path.c_str(), O_RDONLY | O_DIRECTORY | O_CLOEXEC));
    if (!parent) { const int error = errno; fail("The profile folder " + utf8(path) + " could not be opened" + os_error(error) + "."); }
    Fd folder(::openat(parent.value, name.c_str(), O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC));
    if (!folder) {
        const int error = errno;
        if (error == ELOOP || error == ENOTDIR) fail("The profile location " + utf8(path) + " is not an ordinary folder.");
        fail("The profile folder " + utf8(path) + " could not be opened" + os_error(error) + ".");
    }
    return folder;
}

Fd open_saves(int profile, const fs::path& shown) {
    Fd saves(::openat(profile, "saves", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC));
    if (saves) return saves;
    const int error = errno;
    if (error == ENOENT) return {};
    if (error == ELOOP || error == ENOTDIR)
        fail("The saves location " + utf8(shown) + " is not an ordinary folder. Nothing was copied.");
    fail("The saves folder " + utf8(shown) + " could not be inspected" + os_error(error) + ".");
}

// Links, folders and missing entries have no ordinary size.
std::optional<std::uintmax_t> ordinary_size(const fs::path& path) {
    struct stat st{};
    if (::lstat(path.c_str(), &st) || !S_ISREG(st.st_mode)) return std::nullopt;
    return std::uintmax_t(st.st_size);
}

void copy_ordinary(int from, const std::string& name, int to, const fs::path& shown) {
    const auto bytes = read_ordinary(from, name.c_str(), shown);
    if (bytes && !publish_new(to, name, *bytes)) fail(utf8(shown) + " could not be copied: the copy already exists");
}

void write_record(int profile, const fs::path& shown_root, const std::string& text) {
    const auto shown = shown_root / record_file.c_str();
    try {
        if (!publish_new(profile, record_file.c_str(), text + '\n'))
            std::fprintf(stderr, "player kept the existing %s\n", utf8(shown).c_str());
    } catch (const std::exception& error) {
        std::fprintf(stderr, "player could not write %s: %s\n", utf8(shown).c_str(), error.what());
    }
}

fs::path home() {
    const char* value = std::getenv("HOME");
    if (!value || !*value) fail("HOME is not set, so no profile folder could be chosen. Nothing was changed.");
    const fs::path path(value);
    if (!path.is_absolute())
        fail("HOME is the relative path \"" + std::string(value) + "\", so no profile folder could be chosen. Nothing was changed.");
    return path.lexically_normal();
}
// XDG: an unset or empty XDG_DATA_HOME means $HOME/.local/share; a relative one is refused, never resolved.
fs::path data_home() {
    const char* value = std::getenv("XDG_DATA_HOME");
    if (!value || !*value) return home() / ".local" / "share";
    const fs::path path(value);
    if (!path.is_absolute())
        fail("XDG_DATA_HOME is the relative path \"" + std::string(value) +
            "\". Set it to an absolute folder or unset it, then start the game again. Nothing was changed.");
    return path.lexically_normal();
}
// Missing folders are created private; existing ones are used as they are.
void ensure_private_directories(const fs::path& path) {
    fs::path built = path.root_path();
    for (const auto& part : path.relative_path()) {
        built /= part;
        if (::mkdir(built.c_str(), 0700) && errno != EEXIST) {
            const int error = errno;
            fail("The folder " + utf8(built) + " could not be created" + os_error(error) + ". Nothing was changed.");
        }
    }
}

// Invalid UTF-8 from runtime text becomes '?'; SDL requires UTF-8.
std::string displayable(std::string_view text) {
    std::string out;
    for (std::size_t i = 0; i < text.size();) {
        const unsigned char c = static_cast<unsigned char>(text[i]);
        const std::size_t n = c < 0x80 ? 1 : (c >> 5) == 6 ? 2 : (c >> 4) == 14 ? 3 : (c >> 3) == 30 ? 4 : 0;
        bool valid = n != 0 && i + n <= text.size() && c != 0;
        for (std::size_t k = 1; valid && k < n; ++k) valid = (static_cast<unsigned char>(text[i + k]) & 0xC0) == 0x80;
        if (valid) { out.append(text.substr(i, n)); i += n; }
        else { out += '?'; ++i; }
    }
    return out;
}
// SDL documents a parentless message box as main-thread only; it may run before
// SDL_Init. Returns the chosen id, -1 when closed without a choice, -2 when none could be shown.
struct Button { int id; const char* label; Uint32 flags; };
int message_box(const std::string& text, Uint32 kind, std::initializer_list<Button> buttons) {
    if (!on_main_thread()) return -2;
    std::vector<SDL_MessageBoxButtonData> data;
    for (const auto& button : buttons) data.push_back({button.flags, button.id, button.label});
    const auto message = displayable(text);
    const SDL_MessageBoxData box{kind, nullptr, title, message.c_str(), int(data.size()), data.data(), nullptr};
    int chosen = -1;
    if (SDL_ShowMessageBox(&box, &chosen) < 0) {
        std::fprintf(stderr, "player dialog unavailable: %s\n", SDL_GetError());
        return -2;
    }
    return chosen;
}

bool ask_import(const fs::path& source) {
    const auto text = "Saved progress from an earlier Banjo-Tooie: Recompiled alpha was found:\n" + utf8(source) +
        "\n\nCopy it into your new Banjo-Tooie: Scurvy Dog Port profile?\n\nThe original file is left unchanged. "
        "Settings and practice states are not copied. You will not be asked again.";
    const int answer = message_box(text, SDL_MESSAGEBOX_INFORMATION,
        {{1, "Yes", SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT}, {0, "No", 0}});
    if (answer < 0) throw NoAnswer{};
    return answer == 1;
}
}

std::string utf8(const fs::path& path) { return path.native(); }

std::vector<std::string> command_line(int argc, char** argv) {
    std::vector<std::string> result;
    for (int i = 1; i < argc; ++i) result.emplace_back(argv[i]);
    return result;
}

fs::path default_profile_root() {
    const auto data = data_home();
    ensure_private_directories(data);
    return data / product_folder;
}
fs::path previous_profile_root() { return data_home() / previous_folder; }
fs::path legacy_save_path() { return home() / ".config" / legacy_folder / "saves" / save_file.c_str(); }

Profile::Profile(fs::path root, int directory, fs::path storage)
    : root_(std::move(root)), storage_(std::move(storage)), directory_(directory) {
    std::lock_guard lock(held_mutex);
    held.push_back({directory_, root_, storage_});
}
Profile::Profile(Profile&& other) noexcept
    : root_(std::move(other.root_)), storage_(std::move(other.storage_)), directory_(std::exchange(other.directory_, -1)) {}
Profile::~Profile() {
    if (directory_ < 0) return;
    {
        std::lock_guard lock(held_mutex);
        std::erase_if(held, [&](const Held& entry) { return entry.fd == directory_; });
    }
    ::close(directory_);
}

Profile Profile::acquire(const fs::path& requested) {
    const auto [parent_path, name] = place(requested);
    const auto root = parent_path / name;
    Fd parent(::open(parent_path.c_str(), O_RDONLY | O_DIRECTORY | O_CLOEXEC));
    if (!parent) {
        const int error = errno;
        fail("The profile folder " + utf8(root) + " could not be created" + os_error(error) +
            ". Check that its parent folder exists and can be written.");
    }
    bool created = false;
    Fd folder(::openat(parent.value, name.c_str(), O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC));
    if (!folder && errno == ENOENT) {
        // A new root is private; an existing folder's permissions are never changed.
        if (::mkdirat(parent.value, name.c_str(), 0700) == 0) created = true;
        else if (errno != EEXIST) {
            const int error = errno;
            fail("The profile folder " + utf8(root) + " could not be created" + os_error(error) +
                ". Check that its parent folder exists and can be written.");
        }
        folder = Fd(::openat(parent.value, name.c_str(), O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC));
    }
    if (!folder) {
        const int error = errno;
        if (error == ELOOP || error == ENOTDIR)
            fail("The profile location " + utf8(root) + " is not an ordinary folder. Rename it or choose another "
                "folder, then start the game again. Nothing was changed.");
        fail("The profile folder " + utf8(root) + " could not be opened" + os_error(error) + ".");
    }
    // The held folder is the lock: a rename keeps it; a replacement is another inode and lock.
    if (::flock(folder.value, LOCK_EX | LOCK_NB)) {
        const int error = errno;
        if (error == EWOULDBLOCK) fail(in_use(root));
        fail("The profile folder " + utf8(root) + " could not be locked" + os_error(error) + ".");
    }
    struct stat held_stat{}, named{};
    if (::fstat(folder.value, &held_stat) || ::fstatat(parent.value, name.c_str(), &named, AT_SYMLINK_NOFOLLOW) ||
        !same_inode(held_stat, named))
        fail("The profile folder " + utf8(root) + " changed while it was being opened. Nothing was changed.");
    switch (read_marker(folder.value, root)) {
    case Marker::Matches: break;
    case Marker::Different:
        fail("The folder " + utf8(root) + " has a profile marker this version does not recognize. Nothing was changed.");
    case Marker::Absent: {
        if (!directory_empty(folder.value, root))
            fail("The folder " + utf8(root) + " already contains files that are not a Banjo-Tooie: Scurvy Dog Port profile. "
                "Move them elsewhere or choose another folder. Nothing was changed.");
        bool published = false;
        try { published = publish_new(folder.value, marker_file.c_str(), marker_bytes); }
        catch (const Failure& failure) {
            fail("The profile folder " + utf8(root) + " could not be marked (" + failure.what() +
                "). Check that the folder can be written.");
        }
        if (!published || read_marker(folder.value, root) != Marker::Matches) fail(in_use(root));
        break;
    }
    }
    if (created && ::fsync(parent.value)) {
        const int error = errno;
        fail("The profile folder " + utf8(root) + " could not be flushed to disk" + os_error(error) + ".");
    }
    // Runtime storage goes through the held descriptor for the process lifetime.
#ifdef __APPLE__
    // No path reaches a held directory descriptor here: use the descriptor's current path, checked below
    // to be the held inode, so only a rename of the root while the game runs goes unnoticed.
    char resolved[PATH_MAX];
    if (::fcntl(folder.value, F_GETPATH, resolved))
        fail("This system could not name the profile folder it opened. Nothing was started.");
    auto storage = fs::path(resolved);
    const char* storage_missing = "This system did not return the profile folder it opened. Nothing was started.";
#else
    auto storage = fs::path("/proc/self/fd") / std::to_string(folder.value);
    const char* storage_missing = "This system does not provide /proc/self/fd, which Banjo-Tooie: Scurvy Dog Port needs to keep using "
        "the profile folder it opened. Nothing was started.";
#endif
    struct stat anchored{};
    if (::stat(storage.c_str(), &anchored) || !same_inode(anchored, held_stat))
        fail(storage_missing);
    return Profile(root, folder.release(), std::move(storage));
}

Migration migrate_profile(const fs::path& previous, const fs::path& destination) {
    const auto [old_parent_path, old_name] = place(previous);
    const auto [new_parent_path, new_name] = place(destination);
    const auto old_root = old_parent_path / old_name, new_root = new_parent_path / new_name;
    const auto kept = "Nothing was copied, and your progress in " + utf8(old_root) + " is unchanged.";
    Fd new_parent(::open(new_parent_path.c_str(), O_RDONLY | O_DIRECTORY | O_CLOEXEC));
    if (!new_parent) {
        const int error = errno;
        fail("The folder " + utf8(new_parent_path) + " could not be opened" + os_error(error) + ". " + kept);
    }
    // Any existing destination wins, even an empty folder or a link; nothing is merged into it.
    struct stat existing{};
    if (::fstatat(new_parent.value, new_name.c_str(), &existing, AT_SYMLINK_NOFOLLOW) == 0)
        return {Migration::DestinationExists, "player profile migration: none; " + utf8(new_root) + " exists"};
    if (errno != ENOENT) {
        const int error = errno;
        fail("The profile folder " + utf8(new_root) + " could not be inspected" + os_error(error) + ". " + kept);
    }
    Fd old_parent(::open(old_parent_path.c_str(), O_RDONLY | O_DIRECTORY | O_CLOEXEC));
    if (!old_parent) {
        const int error = errno;
        if (error == ENOENT || error == ENOTDIR)
            return {Migration::SourceMissing, "player profile migration: none; no " + utf8(old_root)};
        fail("The earlier profile " + utf8(old_root) + " could not be opened" + os_error(error) + ". " + kept);
    }
    const Migration unrecognized{Migration::SourceUnrecognized,
        "player profile migration: none; " + utf8(old_root) + " is not a recognized profile and was left unchanged"};
    Fd old_folder(::openat(old_parent.value, old_name.c_str(), O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC));
    if (!old_folder) {
        const int error = errno;
        if (error == ENOENT) return {Migration::SourceMissing, "player profile migration: none; no " + utf8(old_root)};
        if (error == ELOOP || error == ENOTDIR) return unrecognized;
        fail("The earlier profile " + utf8(old_root) + " could not be opened" + os_error(error) + ". " + kept);
    }
    // Shared: a copy holding the earlier profile (its exclusive lock) refuses this read.
    if (::flock(old_folder.value, LOCK_SH | LOCK_NB)) {
        const int error = errno;
        if (error == EWOULDBLOCK) fail(in_use(old_root) + " " + kept);
        fail("The earlier profile " + utf8(old_root) + " could not be locked" + os_error(error) + ". " + kept);
    }
    if (read_marker(old_folder.value, old_root) != Marker::Matches) return unrecognized;
    const auto old_saves_path = old_root / "saves";
    Fd old_saves(::openat(old_folder.value, "saves", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC));
    if (!old_saves) {
        const int error = errno;
        if (error == ELOOP || error == ENOTDIR)
            fail("The earlier saves location " + utf8(old_saves_path) + " is not an ordinary folder. " + kept);
        if (error != ENOENT)
            fail("The earlier saves folder " + utf8(old_saves_path) + " could not be opened" + os_error(error) + ". " + kept);
    }
    // A new private sibling owned by this attempt alone; marked last. A failed
    // attempt keeps it, unused and named, for the player.
    std::string stage_name;
    for (unsigned attempt = 1;; ++attempt) {
        stage_name = new_name + ".migrating-" + std::to_string(::getpid()) + "-" + std::to_string(attempt);
        if (::mkdirat(new_parent.value, stage_name.c_str(), 0700) == 0) break;
        const int error = errno;
        if (error != EEXIST || attempt == 100)
            fail("No folder for the copy could be created next to " + utf8(new_root) + os_error(error) + ". " + kept);
    }
    auto copy_location = new_parent_path / stage_name;
    try {
        Fd stage(::openat(new_parent.value, stage_name.c_str(), O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC));
        struct stat staged{};
        if (!stage || ::fstat(stage.value, &staged) || staged.st_uid != ::geteuid() ||
            !directory_empty(stage.value, copy_location))
            fail("the new folder could not be opened as created");
        if (old_saves) {
            if (::mkdirat(stage.value, "saves", 0700)) {
                const int error = errno;
                fail("the saves folder could not be created" + os_error(error));
            }
            Fd stage_saves(::openat(stage.value, "saves", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC));
            if (!stage_saves) fail("the new saves folder could not be opened");
            // The runtime reads <save>.bak when the save itself cannot be opened.
            for (const auto& file : {std::string(save_file.c_str()), std::string(save_file.c_str()) + ".bak"})
                copy_ordinary(old_saves.value, file, stage_saves.value, old_saves_path / file);
            if (::fsync(stage_saves.value)) fail("the saves copy could not be flushed to disk");
        }
        for (const char* file : {"tooie_imgui.json", rom_name, record_file.c_str()})
            copy_ordinary(old_folder.value, file, stage.value, old_root / file);
        if (read_marker(old_folder.value, old_root) != Marker::Matches) fail("the earlier profile marker changed during the copy");
        if (!publish_new(stage.value, marker_file.c_str(), marker_bytes)) fail("the profile marker could not be written");
        // No replace: a destination that appeared meanwhile wins.
        if (rename_no_replace(new_parent.value, stage_name.c_str(), new_parent.value, new_name.c_str())) {
            const int error = errno;
            if (error == EEXIST || error == ENOTEMPTY) fail(utf8(new_root) + " appeared meanwhile and was left as it is");
            fail("the copy could not be renamed to " + utf8(new_root) + os_error(error));
        }
        copy_location = new_root;
        struct stat published{};
        if (::fstatat(new_parent.value, new_name.c_str(), &published, AT_SYMLINK_NOFOLLOW) || !same_inode(published, staged))
            fail(utf8(new_root) + " was replaced while the copy was being renamed");
        if (::fsync(new_parent.value)) fail("the renamed copy could not be flushed to disk");
    } catch (const std::exception& failure) {
        fail(std::string("Your earlier profile could not be copied: ") + failure.what() + ".\n\nYour original " +
            utf8(old_root) + " is unchanged and still holds your progress. This attempt's copy is kept, unused, in " +
            utf8(copy_location) + ". Start the game again to retry.");
    }
    return {Migration::Migrated,
        "player profile migration: copied " + utf8(old_root) + " to " + utf8(new_root) + "; the original is unchanged"};
}

ImportResult import_save(const fs::path& source, const fs::path& root) {
    fs::path shown_root;
    Fd profile = open_root(root, shown_root);
    const auto saves_shown = shown_root / "saves";
    Fd saves = open_saves(profile.value, saves_shown);
    if (saves && !directory_empty(saves.value, saves_shown)) return ImportResult::DestinationNotEmpty;
    const auto [source_parent, source_name] = place(source);
    Fd parent(::open(source_parent.c_str(), O_RDONLY | O_DIRECTORY | O_CLOEXEC));
    if (!parent) {
        const int error = errno;
        if (error == ENOENT || error == ENOTDIR) return ImportResult::SourceMissing;
        fail("The earlier save " + utf8(source) + " could not be opened" + os_error(error) + ". Nothing was copied.");
    }
    Fd input;
    struct stat before{};
    int error = 0;
    switch (open_regular(parent.value, source_name.c_str(), input, before, error)) {
    case Entry::Missing: return ImportResult::SourceMissing;
    case Entry::NotOrdinary: fail("The save to import, " + utf8(source) + ", is not an ordinary file. Nothing was copied.");
    case Entry::Error:
        fail("The earlier save " + utf8(source) + " could not be opened" + os_error(error) + ". Nothing was copied.");
    case Entry::Opened: break;
    }
    if (std::uintmax_t(before.st_size) != save_bytes) return ImportResult::WrongSize;
    std::string bytes(save_bytes, '\0');
    if (!read_exact(input.value, bytes.data(), bytes.size()))
        fail("The earlier save " + utf8(source) + " could not be read completely. Nothing was copied.");
    // No POSIX equivalent of a deny-write share: refuse any change during the read.
    struct stat after{}, named{};
    if (::fstat(input.value, &after) || !unchanged(before, after) ||
        ::fstatat(parent.value, source_name.c_str(), &named, AT_SYMLINK_NOFOLLOW) || !unchanged(before, named))
        fail("The earlier save " + utf8(source) + " changed while it was being copied. Close Banjo-Tooie: Recompiled, "
            "then start Scurvy Dog Port again. Nothing was copied.");
    bool created = false;
    if (!saves) {
        if (::mkdirat(profile.value, "saves", 0700) == 0) created = true;
        else if (errno != EEXIST) {
            const int mkdir_error = errno;
            fail("The saves folder " + utf8(saves_shown) + " could not be created" + os_error(mkdir_error) + ".");
        }
        saves = open_saves(profile.value, saves_shown);
        if (!saves) fail("The saves folder " + utf8(saves_shown) + " could not be opened.");
    }
    if (!directory_empty(saves.value, saves_shown)) return ImportResult::DestinationNotEmpty;
    bool published = false;
    try {
        // Staged beside the saves folder; never replaces an existing save.
        published = publish_new(saves.value, save_file.c_str(), bytes, {profile.value, "save-import.partial"});
        if (created && ::fsync(profile.value)) fail("the saves folder could not be flushed to disk");
    } catch (const Failure& failure) {
        fail("Your earlier save could not be copied into " + utf8(shown_root) + " (" + failure.what() +
            "). Check free disk space and folder permissions. The original is unchanged.");
    }
    return published ? ImportResult::Imported : ImportResult::DestinationNotEmpty;
}

bool offer_import(const fs::path& source, const fs::path& root,
    const std::function<bool(const fs::path&)>& ask) {
    fs::path shown_root;
    Fd profile = open_root(root, shown_root);
    struct stat record{};
    if (::fstatat(profile.value, record_file.c_str(), &record, AT_SYMLINK_NOFOLLOW) == 0) return false;
    if (errno != ENOENT) {
        const int error = errno;
        fail("The import record in " + utf8(shown_root) + " could not be inspected" + os_error(error) + ".");
    }
    Fd saves = open_saves(profile.value, shown_root / "saves");
    if (saves && !directory_empty(saves.value, shown_root / "saves")) return false;
    const auto size = ordinary_size(source);
    if (!size) return false;
    if (*size != save_bytes) {
        std::fprintf(stderr, "player ignored older save %s: %llu bytes\n", utf8(source).c_str(),
            static_cast<unsigned long long>(*size));
        return false;
    }
    if (!ask(source)) {
        write_record(profile.value, shown_root, "declined: " + utf8(source));
        return false;
    }
    if (import_save(source, root) != ImportResult::Imported)
        fail("Your earlier save changed while it was being copied and was not imported. "
            "Start the game again to retry.");
    write_record(profile.value, shown_root, "imported: " + utf8(source));
    std::fprintf(stderr, "player imported older save %s\n", utf8(source).c_str());
    return true;
}

void prepare_saves(const Arguments& arguments, const fs::path& root) {
    if (arguments.import_save.empty()) {
        if (arguments.qa) return;
        fs::path legacy;
        try { legacy = legacy_save_path(); }
        catch (const Failure& failure) {
            std::fprintf(stderr, "player older-save offer skipped: %s\n", failure.what());
            return;
        }
        try { offer_import(legacy, root, ask_import); }
        catch (const NoAnswer&) {
            std::fputs("player older-save offer was not answered; it will be offered again\n", stderr);
        }
        return;
    }
    switch (import_save(arguments.import_save, root)) {
    case ImportResult::Imported:
        std::fprintf(stderr, "player imported save %s\n", utf8(arguments.import_save).c_str());
        return;
    case ImportResult::DestinationNotEmpty:
        std::fprintf(stderr, "player kept the existing profile save; --import-save ignored\n");
        return;
    case ImportResult::SourceMissing:
        fail("The save to import was not found: " + utf8(arguments.import_save));
    case ImportResult::WrongSize:
        fail("The save to import is not a " + std::to_string(save_bytes) + "-byte Banjo-Tooie save: " +
            utf8(arguments.import_save));
    }
}

void open_log(const fs::path& root) {
    try {
        fs::path shown_root;
        Fd profile = open_root(root, shown_root);
        const uid_t owner = ::geteuid();
        // 1 ordinary own log, 0 absent, -1 anything else (link, hard link, other type or owner).
        const auto state = [&](const char* name) {
            struct stat st{};
            if (::fstatat(profile.value, name, &st, AT_SYMLINK_NOFOLLOW)) return errno == ENOENT ? 0 : -1;
            return S_ISREG(st.st_mode) && st.st_nlink == 1 && st.st_uid == owner ? 1 : -1;
        };
        const int current = state("player.log");
        if (current < 0) {
            std::fputs("player log refused: player.log is not this profile's ordinary log; nothing was changed\n", stderr);
            return;
        }
        // Renames only this profile's own ordinary logs; a link or other entry is left untouched.
        if (current == 1) {
            if (state("player-previous.log") >= 0)
                ::renameat(profile.value, "player.log", profile.value, "player-previous.log");
            else
                std::fputs("player log rotation skipped: player-previous.log is not an ordinary log\n", stderr);
        }
        Fd log(::openat(profile.value, "player.log", O_WRONLY | O_APPEND | O_CREAT | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC, 0600));
        if (!log) {
            const int error = errno;
            std::fprintf(stderr, "player log not opened%s\n", os_error(error).c_str());
            return;
        }
        struct stat st{};
        if (::fstat(log.value, &st) || !S_ISREG(st.st_mode) || st.st_nlink != 1 || st.st_uid != owner) {
            std::fputs("player log refused: the opened player.log is not an ordinary own file\n", stderr);
            return;
        }
        // Both streams append through one open file description; a failure leaves startup unlogged, not blocked.
        std::fflush(stdout);
        std::fflush(stderr);
        if (::dup2(log.value, STDERR_FILENO) < 0) return;
        ::dup2(log.value, STDOUT_FILENO);
        log_file = shown_root / "player.log";
        std::fprintf(stderr, "%s %s\nprofile=%s\n", build::product, build::version, utf8(shown_root).c_str());
    } catch (const std::exception& error) {
        std::fprintf(stderr, "player log not opened: %s\n", error.what());
    }
}

std::optional<fs::path> pick_rom() {
    if (!on_main_thread()) fail("The file picker can only open from the main thread.");
    if (NFD_Init() != NFD_OKAY) {
        const char* error = NFD_GetError();
        fail(std::string("The file picker could not open (") + (error ? error : "unknown error") + ").");
    }
    nfdnchar_t* chosen = nullptr;
    const nfdnfilteritem_t filters[] = {{"N64 ROM", "z64,n64,v64"}};
    const nfdresult_t result = NFD_OpenDialogN(&chosen, filters, 1, nullptr);
    std::optional<fs::path> path;
    std::string problem;
    if (result == NFD_OKAY) {
        path = fs::path(chosen); // Native bytes; never transcoded.
        NFD_FreePathN(chosen);
    } else if (result == NFD_ERROR) {
        const char* error = NFD_GetError();
        problem = error ? error : "unknown error";
    }
    NFD_Quit();
    if (!problem.empty()) fail("The file picker could not open (" + problem + ").");
    return path;
}

bool ask_retry(const std::string& text) {
    return message_box(text, SDL_MESSAGEBOX_WARNING,
        {{1, "Retry", SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT}, {0, "Cancel", SDL_MESSAGEBOX_BUTTON_ESCAPEKEY_DEFAULT}}) == 1;
}

void set_log_only_errors() noexcept { log_only_errors.store(true, std::memory_order_release); }

bool show_error(const std::string& text) noexcept {
    try {
        std::fprintf(stderr, "player error: %s\n", text.c_str());
        if (log_only_errors.load(std::memory_order_acquire)) return false;
        if (!on_main_thread()) {
            // Runtime workers report here too; a parentless SDL dialog is main-thread only.
            std::fputs("player error dialog not shown: reported off the main thread\n", stderr);
            return false;
        }
        auto message = text;
        if (!log_file.empty()) message += "\n\nDetails were written to:\n" + utf8(log_file);
        return message_box(message, SDL_MESSAGEBOX_ERROR, {{0, "OK", SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT}}) >= -1;
    } catch (...) {
        return false;
    }
}
}
