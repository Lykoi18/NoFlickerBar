class Noflickerbar < Formula
  desc "Stops the idle flicker of a faulty MacBook Pro Touch Bar"
  homepage "https://github.com/Lykoi18/NoFlickerBar"
  url "https://github.com/Lykoi18/NoFlickerBar/archive/refs/tags/v1.0.2.tar.gz"
  sha256 "42eb4656eb3685055f6cc7ff971b3359bb716155c838a8bfc1d4b1a3de394ce9"
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
      If you installed NoFlickerBar with install.sh or make install before,
      remove that copy first so two instances do not run.
    EOS
  end

  test do
    assert_equal version.to_s, shell_output("#{bin}/noflickerbar --version").strip
  end
end
