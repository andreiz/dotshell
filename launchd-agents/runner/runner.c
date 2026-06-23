// runner — generic launcher for TCC-sensitive launchd agents.
//
// macOS attributes privacy permissions (Full Disk Access, etc.) to the
// executing Mach-O binary / app bundle, NOT to shell scripts. So a launchd
// agent that needs to touch protected folders (~/Downloads, ~/Documents…)
// can't get there by running a .sh directly — the grant would have to live on
// /bin/bash, which is broad and leaky.
//
// Instead, every such agent runs THIS compiled binary (shipped inside
// AgentRunner.app and ad-hoc signed with a stable bundle id). Full Disk Access
// is granted ONCE to the bundle. The agent's plist passes the real program to
// run as arguments:
//
//   ProgramArguments:
//     /…/AgentRunner.app/Contents/MacOS/runner
//     /…/bin/heic2jpeg.sh           <- argv[1], the target ("config")
//     [extra args…]                 <- argv[2..], forwarded verbatim
//
// runner spawns the target as a CHILD process and waits for it. Children
// inherit the bundle as their TCC "responsible process", so the bundle's FDA
// grant covers the spawned script (and the bash it shebangs into). Using a
// child (not execv) is deliberate: it keeps this bundle alive as the
// responsible process for the whole subtree.

#include <spawn.h>
#include <sys/wait.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>

extern char **environ;

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "runner: usage: runner <program> [args...]\n");
        return 2;
    }

    pid_t pid;
    // Spawn argv[1] with argv[1..] as its argv (so the target sees itself as $0).
    int rc = posix_spawn(&pid, argv[1], NULL, NULL, &argv[1], environ);
    if (rc != 0) {
        fprintf(stderr, "runner: posix_spawn(%s) failed: %s\n", argv[1], strerror(rc));
        return 127;
    }

    int status;
    while (waitpid(pid, &status, 0) < 0) {
        if (errno != EINTR) {
            perror("runner: waitpid");
            return 127;
        }
    }

    if (WIFEXITED(status))   return WEXITSTATUS(status);
    if (WIFSIGNALED(status)) return 128 + WTERMSIG(status);
    return 1;
}
