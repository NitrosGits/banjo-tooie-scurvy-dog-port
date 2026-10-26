// Synthetic Linux custody fixture for tools/baseline/player_startup_posix.cpp.
// Everything happens beneath one new mkdtemp folder under argv[1] or the system temp folder; no personal,
// production, game, ROM or save data is read and no dialog or picker opens.
// The folder is left for inspection; nothing is removed.
#include "player_startup.hpp"
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iterator>
#include <string>
#include <vector>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

namespace fs = std::filesystem;
namespace player = baseline::player;

namespace {
int failures = 0;
#define CHECK(condition) do { if (!(condition)) { std::printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #condition); ++failures; } } while (0)

std::string ascii(const wchar_t* text) { std::string out; while (*text) out += char(*text++); return out; }
const std::string marker_file = ascii(player::marker_name), save_file = ascii(player::save_name),
    record_file = ascii(player::import_record_name);
const std::string marker(player::marker_text, sizeof(player::marker_text) - 1);

void write(const fs::path& path, const std::string& bytes) {
    std::ofstream out(path, std::ios::binary);
    out.write(bytes.data(), std::streamsize(bytes.size()));
}
std::string read(const fs::path& path) {
    std::ifstream in(path, std::ios::binary);
    return {std::istreambuf_iterator<char>(in), {}};
}
#ifdef __APPLE__
const timespec& mtime_of(const struct stat& st) { return st.st_mtimespec; }
#else
const timespec& mtime_of(const struct stat& st) { return st.st_mtim; }
#endif
struct stat entry(const fs::path& path) { struct stat st{}; ::lstat(path.c_str(), &st); return st; }
bool present(const fs::path& path) { struct stat st{}; return ::lstat(path.c_str(), &st) == 0; }
bool same_inode(const struct stat& a, const struct stat& b) { return a.st_dev == b.st_dev && a.st_ino == b.st_ino; }
template <class F> bool refused(F&& action, std::string_view contains) {
    try { action(); }
    catch (const player::Failure& failure) { return std::string_view(failure.what()).find(contains) != std::string_view::npos; }
    return false;
}
// Locks and stdio redirection stay isolated in a child.
template <class F> int in_child(F&& body) {
    std::fflush(nullptr);
    const pid_t pid = ::fork();
    if (pid == 0) std::_Exit(body() ? 0 : 1);
    int status = 0;
    ::waitpid(pid, &status, 0);
    return WIFEXITED(status) ? WEXITSTATUS(status) : 99;
}
// Sorted inode/size/mtime/mode/bytes of the root and every entry; links not followed.
std::string fingerprint(const fs::path& root) {
    std::vector<std::string> lines;
    const auto describe = [&](const fs::path& path) {
        const auto st = entry(path);
        auto line = path.native() + ' ' + std::to_string(st.st_ino) + ' ' + std::to_string(st.st_size) + ' ' +
            std::to_string(mtime_of(st).tv_sec) + '.' + std::to_string(mtime_of(st).tv_nsec) + ' ' + std::to_string(st.st_mode);
        if (S_ISREG(st.st_mode)) line += ' ' + read(path);
        lines.push_back(std::move(line));
    };
    describe(root);
    for (const auto& item : fs::recursive_directory_iterator(root)) describe(item.path());
    std::sort(lines.begin(), lines.end());
    std::string out;
    for (const auto& line : lines) out += line + '\n';
    return out;
}

void unicode_arguments(const fs::path& base) {
    const std::string folder = (base / "profile-\xC3\xBC-\xE6\x97\xA5\xE6\x9C\xAC").native();
    const std::string rom = (base / "rom-\xFF.z64").native(); // Not UTF-8: native bytes survive too.
    const auto parsed = player::parse_arguments({"--profile-dir", folder, "--rom", rom, "--seconds", "5"});
    CHECK(parsed.qa && parsed.seconds == 5 && parsed.profile.native() == folder && parsed.rom.native() == rom);
    CHECK(player::parse_arguments({}).profile.empty());
    CHECK(refused([&] { player::parse_arguments({"--rom", rom}); }, "--profile-dir"));
    CHECK(refused([&] { player::parse_arguments({"--profile-dir", folder, "--input-script", rom}); }, "--seconds"));
    CHECK(refused([&] { player::parse_arguments({"--profile-dir", folder, "--seconds", "901"}); }, "1..900"));
    const auto profile = player::Profile::acquire(parsed.profile);
    CHECK(read(parsed.profile / marker_file) == marker && player::utf8(profile.root()) == folder);
    CHECK((entry(parsed.profile).st_mode & 0077) == 0); // A new root is private.
#ifdef __APPLE__
    CHECK(entry(profile.storage()).st_ino == entry(parsed.profile).st_ino); // No descriptor path: the held folder's own path.
#else
    CHECK(profile.storage().native().rfind("/proc/self/fd/", 0) == 0);
#endif
}

void two_process_lock(const fs::path& base) {
    const auto root = base / "locked";
    {
        const auto holder = player::Profile::acquire(root);
        CHECK(in_child([&] { return refused([&] { player::Profile::acquire(root); }, "already using"); }) == 0);
    }
    CHECK(in_child([&] { player::Profile::acquire(root); return true; }) == 0);
}

void links_and_types(const fs::path& base) {
    const auto real = base / "real";
    fs::create_directory(real);
    fs::create_directory_symlink(real, base / "linked");
    CHECK(refused([&] { player::Profile::acquire(base / "linked"); }, "not an ordinary folder") && fs::is_empty(real));
    write(base / "plain", "x");
    CHECK(refused([&] { player::Profile::acquire(base / "plain"); }, "not an ordinary folder") && read(base / "plain") == "x");
    const auto fifo = base / "fifo-marker";
    fs::create_directory(fifo);
    CHECK(::mkfifo((fifo / marker_file).c_str(), 0600) == 0);
    CHECK(refused([&] { player::Profile::acquire(fifo); }, "does not recognize")); // Never blocks on the FIFO.
    const auto link_marker = base / "link-marker";
    fs::create_directory(link_marker);
    write(base / "marker-elsewhere", marker);
    fs::create_symlink(base / "marker-elsewhere", link_marker / marker_file);
    CHECK(refused([&] { player::Profile::acquire(link_marker); }, "does not recognize"));
    const auto unmarked = base / "unmarked";
    fs::create_directory(unmarked);
    write(unmarked / "personal.txt", "mine");
    CHECK(refused([&] { player::Profile::acquire(unmarked); }, "not a Banjo-Tooie"));
    CHECK(read(unmarked / "personal.txt") == "mine" && !present(unmarked / marker_file));
}

void marker_mutation(const fs::path& base) {
    int index = 0;
    for (const auto& bytes : {marker + "x", marker.substr(0, 5), std::string("Banjo-Tooie: Encore profile v2\n")}) {
        const auto root = base / ("marker-" + std::to_string(++index));
        fs::create_directory(root);
        write(root / marker_file, bytes);
        write(root / "keep.txt", "keep");
        CHECK(refused([&] { player::Profile::acquire(root); }, "does not recognize"));
        CHECK(read(root / marker_file) == bytes && read(root / "keep.txt") == "keep");
    }
}

void migration(const fs::path& base) {
    const auto old_root = base / "old";
    fs::create_directories(old_root / "saves");
    write(old_root / marker_file, marker);
    write(old_root / "saves" / save_file, std::string(player::save_bytes, '\x5A'));
    write(old_root / "saves" / (save_file + ".bak"), std::string(player::save_bytes, '\x5B'));
    write(old_root / "tooie_imgui.json", "{}");
    write(old_root / "unlisted.txt", "not copied");
    const auto before = fingerprint(old_root);
    const auto result = player::migrate_profile(old_root, base / "new");
    CHECK(result.outcome == player::Migration::Migrated);
    CHECK(read(base / "new" / "saves" / save_file) == std::string(player::save_bytes, '\x5A'));
    CHECK(read(base / "new" / marker_file) == marker && !present(base / "new" / "unlisted.txt"));
    CHECK(fingerprint(old_root) == before); // The personal source is only read.
    const auto destination = fingerprint(base / "new");
    CHECK(player::migrate_profile(old_root, base / "new").outcome == player::Migration::DestinationExists);
    CHECK(fingerprint(base / "new") == destination); // An existing destination wins unchanged.
    CHECK(player::migrate_profile(base / "absent-old", base / "new2").outcome == player::Migration::SourceMissing);
    const auto unmarked = base / "old-unmarked";
    fs::create_directory(unmarked);
    write(unmarked / "x", "y");
    CHECK(player::migrate_profile(unmarked, base / "new3").outcome == player::Migration::SourceUnrecognized);
    CHECK(!present(base / "new2") && !present(base / "new3"));
    // A failed attempt keeps its unmarked folder, unused and named.
    const auto bad = base / "old-bad";
    fs::create_directories(bad / "saves" / save_file); // A folder where the save should be.
    write(bad / marker_file, marker);
    std::string message;
    try { player::migrate_profile(bad, base / "new-bad"); } catch (const player::Failure& failure) { message = failure.what(); }
    const auto stage = base / ("new-bad.migrating-" + std::to_string(::getpid()) + "-1");
    CHECK(!message.empty() && message.find(stage.native()) != std::string::npos);
    CHECK(S_ISDIR(entry(stage).st_mode) && !present(stage / marker_file) && !present(base / "new-bad"));
    // A copy holding the earlier profile refuses the migration.
    const auto holder = player::Profile::acquire(old_root);
    CHECK(refused([&] { player::migrate_profile(old_root, base / "new-held"); }, "already using") && !present(base / "new-held"));
}

void import_rules(const fs::path& base) {
    const auto root = base / "import";
    const auto profile = player::Profile::acquire(root);
    const std::string bytes(player::save_bytes, '\x11');
    write(base / "short.bin", std::string(player::save_bytes - 1, 'a'));
    CHECK(player::import_save(base / "short.bin", profile.storage()) == player::ImportResult::WrongSize);
    CHECK(player::import_save(base / "missing.bin", profile.storage()) == player::ImportResult::SourceMissing);
    write(base / "source.bin", bytes);
    fs::create_symlink(base / "source.bin", base / "link.bin");
    CHECK(refused([&] { player::import_save(base / "link.bin", profile.storage()); }, "not an ordinary file"));
    const auto source_before = entry(base / "source.bin");
    CHECK(player::import_save(base / "source.bin", profile.storage()) == player::ImportResult::Imported);
    const auto source_after = entry(base / "source.bin");
    CHECK(read(root / "saves" / save_file) == bytes && read(base / "source.bin") == bytes);
    CHECK(mtime_of(source_before).tv_nsec == mtime_of(source_after).tv_nsec && mtime_of(source_before).tv_sec == mtime_of(source_after).tv_sec);
    write(base / "other.bin", std::string(player::save_bytes, '\x22'));
    CHECK(player::import_save(base / "other.bin", profile.storage()) == player::ImportResult::DestinationNotEmpty);
    CHECK(read(root / "saves" / save_file) == bytes);
    CHECK(std::distance(fs::directory_iterator(root / "saves"), fs::directory_iterator{}) == 1); // No visible stage.
}

void offer_rules(const fs::path& base) {
    write(base / "legacy.bin", std::string(player::save_bytes, '\x33'));
    {
        const auto root = base / "offer-decline";
        const auto profile = player::Profile::acquire(root);
        int asked = 0;
        CHECK(!player::offer_import(base / "legacy.bin", profile.storage(), [&](const fs::path&) { ++asked; return false; }));
        CHECK(asked == 1 && read(root / record_file).rfind("declined: ", 0) == 0 && !present(root / "saves"));
        CHECK(!player::offer_import(base / "legacy.bin", profile.storage(), [&](const fs::path&) { ++asked; return true; }));
        CHECK(asked == 1); // Asked once only.
    }
    {
        const auto root = base / "offer-cancel";
        const auto profile = player::Profile::acquire(root);
        int asked = 0;
        bool propagated = false;
        // Closed or unshown: nothing recorded, offered again.
        try {
            player::offer_import(base / "legacy.bin", profile.storage(),
                [&](const fs::path&) -> bool { ++asked; throw std::runtime_error("closed"); });
        } catch (const std::runtime_error&) { propagated = true; }
        CHECK(propagated && !present(root / record_file));
        CHECK(player::offer_import(base / "legacy.bin", profile.storage(), [&](const fs::path&) { ++asked; return true; }));
        CHECK(asked == 2 && read(root / "saves" / save_file) == std::string(player::save_bytes, '\x33'));
        CHECK(read(root / record_file).rfind("imported: ", 0) == 0 && read(base / "legacy.bin").size() == player::save_bytes);
    }
    {
        write(base / "legacy-short.bin", std::string(100, 'x'));
        const auto root = base / "offer-short";
        const auto profile = player::Profile::acquire(root);
        int asked = 0;
        CHECK(!player::offer_import(base / "legacy-short.bin", profile.storage(), [&](const fs::path&) { ++asked; return true; }));
        CHECK(asked == 0 && !present(root / record_file));
    }
}

void rename_identity(const fs::path& base) {
    const auto root = base / "anchored", moved = base / "anchored-moved";
    write(base / "anchor-source.bin", std::string(player::save_bytes, '\x44'));
    const auto profile = player::Profile::acquire(root);
    fs::rename(root, moved);
    fs::create_directory(root);
    write(root / "decoy.txt", "unrelated");
#ifndef __APPLE__
    // Runtime-style joins through storage stay in the held folder. macOS has no path for a held
    // descriptor, so there storage() names the folder as opened and a move while running is not followed.
    write(profile.storage() / "probe.txt", "held");
    CHECK(read(moved / "probe.txt") == "held" && !present(root / "probe.txt"));
    struct stat anchored{};
    CHECK(::stat(profile.storage().c_str(), &anchored) == 0 && same_inode(anchored, entry(moved)));
#endif
    // Public-root profile work also uses the held folder, never the replacement.
    CHECK(player::import_save(base / "anchor-source.bin", profile.root()) == player::ImportResult::Imported);
    CHECK(present(moved / "saves" / save_file) && !present(root / "saves") && read(root / "decoy.txt") == "unrelated");
    // The replacement is a different folder: refused unmarked, ownable once marked, never this copy's files.
    CHECK(in_child([&] { return refused([&] { player::Profile::acquire(root); }, "not a Banjo-Tooie"); }) == 0);
    write(root / marker_file, marker);
    fs::rename(root / "decoy.txt", base / "decoy-moved.txt");
    CHECK(in_child([&] { player::Profile::acquire(root); return true; }) == 0);
}

void log_refusal(const fs::path& base) {
    write(base / "personal.txt", "personal");
    const auto unchanged_stderr = [&](const char* name, auto&& prepare) {
        return in_child([&] {
            const auto root = base / name;
            const auto profile = player::Profile::acquire(root);
            prepare(root);
            struct stat before{}, after{};
            ::fstat(2, &before);
            player::open_log(profile.root());
            ::fstat(2, &after);
            return same_inode(before, after) && read(base / "personal.txt") == "personal";
        });
    };
    CHECK(unchanged_stderr("log-link", [&](const fs::path& root) { fs::create_symlink(base / "personal.txt", root / "player.log"); }) == 0);
    CHECK(unchanged_stderr("log-hardlink", [&](const fs::path& root) { fs::create_hard_link(base / "personal.txt", root / "player.log"); }) == 0);
    CHECK(in_child([&] {
        const auto root = base / "log-previous-link";
        const auto profile = player::Profile::acquire(root);
        write(root / "player.log", "older\n");
        fs::create_symlink(base / "personal.txt", root / "player-previous.log");
        player::open_log(profile.root());
        struct stat err{};
        ::fstat(2, &err);
        return read(base / "personal.txt") == "personal" && fs::is_symlink(root / "player-previous.log") &&
            same_inode(err, entry(root / "player.log")) && read(root / "player.log").rfind("older\n", 0) == 0;
    }) == 0);
    CHECK(in_child([&] {
        const auto root = base / "log-rotate";
        const auto profile = player::Profile::acquire(root);
        write(root / "player.log", "older run\n");
        player::open_log(profile.root());
        std::fputs("fixture line\n", stderr);
        std::fputs("stdout line\n", stdout);
        std::fflush(stdout);
        std::fflush(stderr);
        struct stat err{}, out{};
        ::fstat(2, &err);
        ::fstat(1, &out);
        const auto log = entry(root / "player.log");
        return read(root / "player-previous.log") == "older run\n" && same_inode(err, log) && same_inode(out, log) &&
            read(root / "player.log").find("fixture line\nstdout line\n") != std::string::npos;
    }) == 0);
}
}

int main(int argc, char** argv) {
    if (argc > 2) { std::fputs("usage: BaselinePlayerStartupTest [PARENT]\n", stderr); return 2; }
    player::set_log_only_errors();
    const fs::path parent = argc == 2 ? fs::path(argv[1]) : fs::temp_directory_path();
    fs::create_directories(parent);
    std::string pattern = (parent / "startup-XXXXXX").native();
    if (!::mkdtemp(pattern.data())) { std::perror("mkdtemp"); return 2; }
    const fs::path base(pattern);
    std::printf("baseline player startup fixture: %s\n", base.c_str());
    unicode_arguments(base);
    two_process_lock(base);
    links_and_types(base);
    marker_mutation(base);
    migration(base);
    import_rules(base);
    offer_rules(base);
    rename_identity(base);
    log_refusal(base);
    std::printf("baseline player startup fixture: %s\n", failures ? "FAIL" : "PASS");
    return failures ? 1 : 0;
}
