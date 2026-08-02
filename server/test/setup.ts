import { $ } from "bun";
import { afterAll } from "bun:test";
import { stopPostgres } from "./harness.ts";

// Testcontainers reads DOCKER_HOST and the default socket path, but does not follow the Docker
// CLI's active context — which is how colima, OrbStack and Rancher expose their daemons.
if (!process.env.DOCKER_HOST) {
  const endpoint =
    await $`docker context inspect --format {{.Endpoints.docker.Host}}`.text();
  process.env.DOCKER_HOST = endpoint.trim();
}

// The reaper container mounts the daemon socket; on a VM-backed runtime the host path it is
// reached by does not exist inside the VM, where the socket is always at this path.
process.env.TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE ??= "/var/run/docker.sock";

afterAll(stopPostgres);
