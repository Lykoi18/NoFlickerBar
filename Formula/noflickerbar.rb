class Noflickerbar < Formula
  desc "Stops the idle flicker of a faulty MacBook Pro Touch Bar"
  homepage "https://github.com/Lykoi18/NoFlickerBar"
  url "https://github.com/Lykoi18/NoFlickerBar/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "aaea76f713aa7ccbdb1f58231e3803bb33949c32898ffc196af36b52cd9b9414"
  license "MIT"

  depends_on :macos

  def install
    # Build for the host architecture only; Homebrew installs per machine.
    system "make", "ARCHS="
    bin.install "build/noflickerbar", "build/dfrbright"
  end

  service do
    run [opt_bin/"noflickerbar"]
    keep_alive successful_exit: false
  end

  def caveats
    <<~EOS
      Start the service now and at every login:
        brew services start noflickerbar
      If you installed NoFlickerBar with install.sh or make install before,
      remove that copy first so two instances do not run.
    EOS
  end

  test do
    assert_equal version.to_s, shell_output("#{bin}/noflickerbar --version").strip
  end
end
