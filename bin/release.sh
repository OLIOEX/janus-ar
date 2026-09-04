#!/bin/bash
#
# Cut a release. Bumps lib/janus-ar/version.rb, refreshes Gemfile.lock, commits
# and tags. Pushing the tag triggers .github/workflows/publish.yml, which
# publishes to RubyGems via trusted publishing.
#
# Usage: bin/release.sh 8.1.0
#
set -euo pipefail

cd "$(dirname "$0")/.."

version="${1:-}"
if [ -z "$version" ]; then
  echo "Usage: bin/release.sh <version>   e.g. bin/release.sh 8.1.0" >&2
  exit 1
fi

if ! [[ "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(\.(.+))?$ ]]; then
  echo "Version must look like MAJOR.MINOR.PATCH[.PRE], got '${version}'" >&2
  exit 1
fi
major="${BASH_REMATCH[1]}"
minor="${BASH_REMATCH[2]}"
patch="${BASH_REMATCH[3]}"
pre="${BASH_REMATCH[5]:-}"
pre_literal="nil"
[ -n "$pre" ] && pre_literal="'${pre}'"

if [ -n "$(git status --porcelain)" ]; then
  echo "Working tree is dirty; commit or clean it before releasing." >&2
  exit 1
fi

if git rev-parse -q --verify "refs/tags/v${version}" >/dev/null; then
  echo "Tag v${version} already exists." >&2
  exit 1
fi

cat > lib/janus-ar/version.rb <<RUBY
# frozen_string_literal: true

module Janus
  unless defined?(::Janus::VERSION)
    module VERSION
      MAJOR = ${major}
      MINOR = ${minor}
      PATCH = ${patch}
      PRE = ${pre_literal}

      def self.to_s
        [MAJOR, MINOR, PATCH, PRE].compact.join('.')
      end
    end
  end
  ::Janus::VERSION
end
RUBY

# Gemfile.lock records the gem's own version, so it has to be regenerated in
# the same commit or the publish workflow will refuse to release.
bundle install --quiet

git add lib/janus-ar/version.rb Gemfile.lock
git commit -m "Release v${version}"
git tag -a "v${version}" -m "Version ${version}"

echo
echo "Committed and tagged v${version}. Push with:"
echo "  git push origin HEAD --follow-tags"
