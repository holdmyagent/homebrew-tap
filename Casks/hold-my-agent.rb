cask "hold-my-agent" do
  version "0.1.0"
  sha256 "82eaff4aab42422602ce75ae8f132506c5c2d18d04d66e69c15a5bf9822d0a42"

  url "https://github.com/holdmyagent/macos/releases/download/v#{version}/HoldMyAgent-#{version}.zip"
  name "Hold My Agent"
  desc "Menu-bar approvals client for Hold My Agent / Arbiter"
  homepage "https://github.com/holdmyagent/macos"

  depends_on macos: ">= :sequoia"

  app "Hold My Agent.app"
end
