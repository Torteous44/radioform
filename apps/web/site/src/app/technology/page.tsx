import Image from "next/image";
import Link from "next/link";
import type { Metadata } from "next";

export default function Technology() {
  return (
    <main className="min-h-screen px-4 sm:px-6 py-12 sm:py-16">
      <div className="max-w-lg mx-auto">
        <div className="relative mt-6 mb-12 hover-underline">
          <Link
            href="/"
            className="absolute top-0 left-0 z-10 text-[12px] text-black hover:border-b hover:border-black"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="14"
              height="14"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
              className="inline-block mr-1 scale-y-[0.9] mb-[0.5px]"
            >
              <path d="M19 12H5" />
              <path d="m12 19-7-7 7-7" />
            </svg>
            Back
          </Link>
          <Image
            src="/demo/radioform.png"
            alt="Radioform menu bar app showing a 10-band equalizer and genre presets"
            width={1024}
            height={1024}
            priority
            className="w-full rounded"
          />
        </div>

        <h1
          className="text-3xl font-normal mb-6"
          style={{ fontFamily: "var(--font-serif)" }}
        >
          How it works
        </h1>

        <div className="text-sm leading-relaxed space-y-10">
          {/* Overview */}
          <section className="space-y-4">
            <p>
              Radioform is a system-wide equalizer for macOS. It sits between
              your apps and your speakers and lets you adjust how everything
              sounds. Spotify, YouTube, FaceTime, games. If your Mac is playing
              it, Radioform can shape it.
            </p>
            <p>
              It runs from your menu bar. You pick a preset or tweak the sliders
              yourself, and then you mostly just leave it alone. That&apos;s
              kind of the whole point.
            </p>
          </section>

          {/* What you can do */}
          <section>
            <h2
              className="text-xl font-normal mb-4"
              style={{ fontFamily: "var(--font-serif)" }}
            >
              What you can do
            </h2>
            <div className="space-y-4">
              <div>
                <p className="font-medium">EQ everything at once</p>
                <p className="text-black">
                  10 bands from 32 Hz to 16 kHz. You can boost the low end on
                  your laptop speakers, pull back harsh highs on your
                  headphones, or add some warmth to a pair of monitors. It
                  applies to all audio on your Mac, so you don&apos;t have to
                  configure anything per app.
                </p>
              </div>
              <div>
                <p className="font-medium">
                  Presets if you don&apos;t want to think about it
                </p>
                <p className="text-black">
                  There are presets for Electronic, Acoustic, Classical,
                  Hip-Hop, Jazz, Pop, R&amp;B, and Rock. They&apos;re reasonable
                  starting points. You can also save your own if you have a
                  curve you like for specific headphones or speakers.
                </p>
              </div>
              <div>
                <p className="font-medium">Switch devices without restarting</p>
                <p className="text-black">
                  Go from your AirPods to your desk speakers to your living room
                  setup. Radioform follows your output device and keeps your EQ
                  applied. Nothing breaks, nothing restarts.
                </p>
              </div>
              <div>
                <p className="font-medium">Built-in limiter</p>
                <p className="text-black">
                  If you push the EQ hard, the limiter and preamp guard keep
                  things from clipping. You can be pretty aggressive with the
                  curve without worrying about distortion.
                </p>
              </div>
            </div>
          </section>

          {/* How it works */}
          <section>
            <h2
              className="text-xl font-normal mb-4"
              style={{ fontFamily: "var(--font-serif)" }}
            >
              Under the hood
            </h2>
            <p className="text-black">
              Radioform installs a virtual audio device on your Mac. All system
              sound passes through it, gets processed by the EQ engine, and
              continues to your actual speakers or headphones.
            </p>
            <p className="text-black mt-4">
              It adds zero latency. The audio is processed sample-by-sample with
              no intermediate buffering, so you won&apos;t notice it&apos;s
              there. Except that things sound better.
            </p>
          </section>

          {/* Performance */}
          <section>
            <h2
              className="text-xl font-normal mb-4"
              style={{ fontFamily: "var(--font-serif)" }}
            >
              Performance
            </h2>
            <p className="text-black">
              Under 1% CPU usage. Zero added latency. 10 EQ bands from 32 Hz to
              16 kHz.
            </p>
          </section>

          {/* Built with */}
          <section>
            <h2
              className="text-xl font-normal mb-4"
              style={{ fontFamily: "var(--font-serif)" }}
            >
              Built with
            </h2>
            <p className="text-black">
              The audio engine is C++. The app is native Swift and SwiftUI, not
              Electron or a web wrapper. It plugs directly into macOS CoreAudio,
              so it feels like something that should have shipped with the OS.
            </p>
          </section>

          {/* Platform */}
          <section>
            <h2
              className="text-xl font-normal mb-4"
              style={{ fontFamily: "var(--font-serif)" }}
            >
              Compatibility
            </h2>
            <div className="space-y-2 text-black">
              <p>macOS 13.0 Ventura or later.</p>
              <p>
                Runs natively on Apple Silicon and Intel. Signed and notarized
                by Apple. Updates happen automatically.
              </p>
              <p>
                Open source under GPLv3. Free, no subscriptions, no data
                collection. It&apos;s just an EQ.
              </p>
            </div>
          </section>
        </div>

        {/* Footer */}
        <p className="text-xs text-neutral-500 mt-16">
          Made by{" "}
          <a href="mailto:contact@pavloscompany.com" className="underline">
            Pavlos Company RSA
          </a>
        </p>
      </div>
    </main>
  );
}
