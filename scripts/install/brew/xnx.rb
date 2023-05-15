#
#   brew tap aiurovet/xnx && brew install xnx
#
#   brew uninstall xnx && brew untap aiurovet/xnx
#
class Xnx < Formula
  # Getting short class name, as "#{name}" gets stripped off the namespace only
  # when reached the install function
  #
  x = "#{name}".split(":")
  $name = x[x.length - 1].downcase

  # Formula description
  #
  desc "Command-line utility for sophisticated search and replace followed by calling external executables"
  license "MIT"
  version "0.2.0"
  homepage "https://aiurovet.com/applications/#{$name}.html"

  # List of all setup variations
  #
  $setups = [{
    "os_name" => "Linux",
    "tar_name" => "#{$name}-#{version}-linux-amd64.tar.gz",
    "base_url" => "https://github.com/aiurovet/#{$name}/raw/release/#{version}/app/Linux/",
    "sha_256" => "f4556de71342b80c0233c0acff6a3ca037d321f25d33cdd61c798b1d87c723a6",
  }, {
    "os_name" => "macOS",
    "tar_name" => "#{$name}-#{version}-macos.tar.gz",
    "base_url" => "https://github.com/aiurovet/#{$name}/raw/release/#{version}/app/macOS/",
    "sha_256" => "2d9a8fa883a91612b7382e9d2fea381709d4666bb0c6c7e2e9596c76b53d9f7c",
  },];

  # Getting this setup and full URL based on the current OS
  #
  $setup = $setups[OS.linux? ? 0 : 1];
  $full_url = $setup["base_url"] + $setup["tar_name"]

  url $full_url
  sha256 $setup["sha_256"]

  # Dummy bottle to avoid enforced build from source. Cacnnot unpack here, as
  # the compiled Dart executable is giving weird output. The actual unpacking
  # is done in the install function
  #
  bottle do
  end

  # Unpack downloaded archive explicitly and create necessary symlinks
  #
  def install
    cellar_root = "#{HOMEBREW_PREFIX}/Cellar/"
    source_path = "#{cellar_root}#{$name}/#{version}/#{$name}"

    system "tar", "-C", "#{cellar_root}", "-x", "-f", cached_download
    bin.install_symlink "#{source_path}"
  end
end
