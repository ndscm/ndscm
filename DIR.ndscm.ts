import { type DirConfig } from "ndscm/config/DIR"

export default {
  bootstrap: {
    pnpm: {
      target: "node_modules",
      watch: "^pnpm-lock.yaml$",
      run: "pnpm install",
    },
  },
  tidy: {
    bazel: {
      target: [
        // sort
        "go.MODULE.bazel",
        "MODULE.bazel",
      ],
      watch: "(^|/)BUILD.bazel$",
      run: "bazel mod tidy",
    },
    go: {
      target: "go.mod",
      watch: "\\.go$",
      run: "go mod tidy -e",
    },
  },
  lock: {
    bazel: {
      target: "MODULE.bazel.lock",
      watch: "(^|/)BUILD.bazel$",
      run: "bazel mod deps --lockfile_mode=update",
    },
    go: {
      target: "go.sum",
      watch: "^go.mod$",
      run: "go mod tidy -e",
    },
  },
  test: {
    bazel_build: {
      watch: "^.*$",
      run: "bazel build //...",
    },
    bazel_test: {
      watch: "^.*$",
      run: "bazel test //...",
    },
  },
} satisfies DirConfig
