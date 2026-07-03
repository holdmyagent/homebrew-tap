# homebrew-tap

Homebrew tap for [Hold My Agent](https://holdmyagent.com), the self-hosted,
fail-closed approval server for AI agents.

## Install

```
brew tap holdmyagent/tap
brew install hma
```

This installs the `hma` command: the Hold My Agent server and dashboard,
built from the `holdmyagent` package on PyPI.

```
hma init
hma --help
```

Source: [github.com/holdmyagent/arbiter](https://github.com/holdmyagent/arbiter)
Website: [holdmyagent.com](https://holdmyagent.com)

## Updating the formula

When a new `holdmyagent` version is published to PyPI, run:

```
scripts/bump.sh
```

This fetches the latest release metadata from PyPI, updates `Formula/hma.rb`'s
`url` and `sha256` to the new sdist, and regenerates the resource (dependency)
blocks with `brew update-python-resources`. The script only edits the
formula and prints a diffstat — review the diff and commit it yourself.

Note: PyPI releases younger than 24 hours are excluded from Homebrew's
dependency resolution (a built-in release-cooldown safety check), so
`scripts/bump.sh` may need to be re-run a day after a new release before it
can see it.

Automating this bump across repositories (opening a PR here whenever a new
`holdmyagent` release lands) is deferred — it requires a GitHub personal
access token with write access to this repository, wired into CI on the
`arbiter` repo.

## License

MIT. See [LICENSE](LICENSE).
