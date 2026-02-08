import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";

export const metadata: Metadata = {
  title: "How Radioform Works — System-Wide macOS Equalizer",
  description:
    "Learn how Radioform works: a native C++ audio engine, virtual audio device, 10-band EQ, built-in presets, and zero-latency system-wide sound processing for macOS.",
  alternates: {
    canonical: "/about",
  },
  openGraph: {
    title: "How Radioform Works — System-Wide macOS Equalizer",
    description:
      "Learn how Radioform works: a native C++ audio engine, virtual audio device, 10-band EQ, built-in presets, and zero-latency system-wide sound processing for macOS.",
    url: "https://radioform.app/about",
    images: [
      {
        url: "/demo/radioform.png",
        width: 1024,
        height: 1024,
        alt: "Radioform menu bar app showing a 10-band equalizer and genre presets",
      },
    ],
  },
};

const aboutJsonLd = {
  "@context": "https://schema.org",
  "@type": "AboutPage",
  name: "How Radioform Works",
  description:
    "Technical details about Radioform's system-wide macOS equalizer: C++ audio engine, virtual audio device, native Swift app, and zero-latency processing.",
  url: "https://radioform.app/about",
  mainEntity: {
    "@type": "SoftwareApplication",
    name: "Radioform",
    url: "https://radioform.app",
  },
};

const DOWNLOAD_URL =
  "https://github.com/Torteous44/radioform/releases/latest/download/Radioform.dmg";
const GITHUB_URL = "https://github.com/Torteous44/radioform";

export default function Technology() {
  return (
    <main className="min-h-screen px-4 sm:px-6 py-12 sm:py-16">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(aboutJsonLd) }}
      />
      <div className="max-w-md mx-auto">
        <div className="relative mt-6 mb-12 hover-underline">
          <Link
            href="/"
            className="absolute top-0 left-0 z-10 text-[10px] text-black  hover:border-black"
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
              className="inline-block mr-1 scale-y-[0.8] mb-0.5"
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
            sizes="(min-width: 640px) 512px, 100vw"
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
              sounds. Spotify, Soundcloud, FaceTime, games. If your Mac is
              playing it, Radioform can shape it.
            </p>
            <p>
              It works by inserting a virtual output device into CoreAudio’s
              chain.
            </p>
            <p>
              It runs from your menu bar. You pick a preset or tweak the sliders
              yourself, and then you mostly just leave it alone. That&apos;s
              kind of the whole point.
            </p>
          </section>
          <section>
            <h2
              className="text-2xl font-normal mb-6"
              style={{ fontFamily: "var(--font-serif)" }}
            >
              What you can do
            </h2>

            <div className="space-y-8">
              <div className="grid grid-cols-12 gap-4">
                <p className="col-span-12 sm:col-span-4 font-medium">
                  EQ everything at once
                </p>
                <p className="col-span-12 sm:col-span-8 text-black leading-relaxed">
                  10 fully parametric bands from 20 Hz to 20 kHz. Boost low end,
                  pull back harsh highs, or add warmth. It applies to all audio
                  on your Mac, so you don’t configure anything per app. Each
                  band is a biquad filter with frequency, Q, and gain.
                </p>
                <div className="col-span-12 h-px bg-black/10 mt-2" />
              </div>

              <div className="grid grid-cols-12 gap-4">
                <p className="col-span-12 sm:col-span-4 font-medium">
                  Presets if you don’t want to think about it
                </p>
                <div className="col-span-12 sm:col-span-8 space-y-2">
                  <p className="text-black leading-relaxed">
                    Presets for Electronic, Acoustic, Classical, Hip-Hop, Pop,
                    R&amp;B, Rock, plus a Flat baseline.
                  </p>
                  <p className="text-black leading-relaxed">
                    They’re solid starting points. Save your own curves for
                    specific headphones or speakers.
                  </p>
                </div>
                <div className="col-span-12 h-px bg-black/10 mt-2" />
              </div>

              <div className="grid grid-cols-12 gap-4">
                <p className="col-span-12 sm:col-span-4 font-medium">
                  Switch devices without restarting
                </p>
                <p className="col-span-12 sm:col-span-8 text-black leading-relaxed">
                  AirPods, desk speakers, living room setup. Radioform follows
                  your output device and keeps your EQ applied. The host
                  reconfigures sample rate automatically.
                </p>
                <div className="col-span-12 h-px bg-black/10 mt-2" />
              </div>

              <div className="grid grid-cols-12 gap-4">
                <p className="col-span-12 sm:col-span-4 font-medium">
                  Built-in limiter
                </p>
                <p className="col-span-12 sm:col-span-8 text-black leading-relaxed">
                  If you push the EQ hard, the limiter and preamp guard help
                  prevent clipping. You can be aggressive without worrying about
                  distortion.
                </p>
              </div>
            </div>
          </section>

          {/* How it works */}
          <section>
            <h2
              className="text-2xl font-normal mb-4"
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
            <p className="text-black mt-4">
              Driver writes to shared memory; the host reads, processes, and
              outputs.
            </p>
          </section>

          {/* Performance */}
          <section>
            <h2
              className="text-2xl font-normal mb-4"
              style={{ fontFamily: "var(--font-serif)" }}
            >
              Performance
            </h2>
            <p className="text-black">
              Under 1% CPU usage. Zero added latency. 10 fully parametric bands
              from 20 Hz to 20 kHz.
            </p>
            <p className="text-black mt-4">
              DSP runs in a separate process with pre-allocated buffers.
            </p>
          </section>

          {/* Built with */}
          <section>
            <h2
              className="text-2xl font-normal mb-4"
              style={{ fontFamily: "var(--font-serif)" }}
            >
              Built with
            </h2>
            <p className="text-black">
              The audio engine is C++. The app is native Swift and SwiftUI, not
              Electron or a web wrapper. It plugs directly into macOS CoreAudio,
              so it feels like something that should have shipped with the OS.
            </p>
            <p className="text-black mt-4">
              HAL plugin + host + UI are separate pieces, loosely coupled.
            </p>
          </section>

          {/* Platform */}
          <section>
            <h2
              className="text-2xl font-normal mb-4"
              style={{ fontFamily: "var(--font-serif)" }}
            >
              Compatibility
            </h2>
            <div className="space-y-2 text-black">
              <p>macOS 13.0 Ventura or later.</p>
              <p>
                Runs natively on Apple Silicon. Releases are signed for
                distribution and can be notarized. In-app update checks are
                handled by Sparkle.
              </p>
              <p>
                Open source under GPLv3. Free, no subscriptions, no data
                collection. It&apos;s just an EQ.
              </p>
            </div>
          </section>
        </div>

        {/* CTA Buttons */}
        <div className="flex flex-col sm:flex-row gap-3 mt-12">
          <button
            disabled
            className="sm:hidden px-5 py-1.5 bg-neutral-300 text-neutral-500 text-sm rounded-full inline-flex items-center justify-center gap-2 cursor-not-allowed"
            style={{
              backgroundImage:
                "radial-gradient(75% 50% at 50% 0%, rgba(255,255,255,0.3) 12%, transparent), radial-gradient(75% 50% at 50% 85%, rgba(255,255,255,0.15), transparent)",
              boxShadow: "inset 0 0 2px 1px rgba(255, 255, 255, 0.2)",
            }}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="14"
              height="14"
              fill="currentColor"
              viewBox="0 0 16 16"
              className="mb-[2px]"
            >
              <path d="M11.182.008C11.148-.03 9.923.023 8.857 1.18c-1.066 1.156-.902 2.482-.878 2.516s1.52.087 2.475-1.258.762-2.391.728-2.43m3.314 11.733c-.048-.096-2.325-1.234-2.113-3.422s1.675-2.789 1.698-2.854-.597-.79-1.254-1.157a3.7 3.7 0 0 0-1.563-.434c-.108-.003-.483-.095-1.254.116-.508.139-1.653.589-1.968.607-.316.018-1.256-.522-2.267-.665-.647-.125-1.333.131-1.824.328-.49.196-1.422.754-2.074 2.237-.652 1.482-.311 3.83-.067 4.56s.625 1.924 1.273 2.796c.576.984 1.34 1.667 1.659 1.899s1.219.386 1.843.067c.502-.308 1.408-.485 1.766-.472.357.013 1.061.154 1.782.539.571.197 1.111.115 1.652-.105.541-.221 1.324-1.059 2.238-2.758q.52-1.185.473-1.282" />
            </svg>
            Download on your mac
          </button>
          <a
            href={DOWNLOAD_URL}
            className="hidden sm:inline-flex btn-primary px-4 py-1.5 text-white text-sm rounded-full items-center justify-center gap-2"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="14"
              height="14"
              fill="currentColor"
              viewBox="0 0 16 16"
              className="mb-[2px]"
            >
              <path d="M11.182.008C11.148-.03 9.923.023 8.857 1.18c-1.066 1.156-.902 2.482-.878 2.516s1.52.087 2.475-1.258.762-2.391.728-2.43m3.314 11.733c-.048-.096-2.325-1.234-2.113-3.422s1.675-2.789 1.698-2.854-.597-.79-1.254-1.157a3.7 3.7 0 0 0-1.563-.434c-.108-.003-.483-.095-1.254.116-.508.139-1.653.589-1.968.607-.316.018-1.256-.522-2.267-.665-.647-.125-1.333.131-1.824.328-.49.196-1.422.754-2.074 2.237-.652 1.482-.311 3.83-.067 4.56s.625 1.924 1.273 2.796c.576.984 1.34 1.667 1.659 1.899s1.219.386 1.843.067c.502-.308 1.408-.485 1.766-.472.357.013 1.061.154 1.782.539.571.197 1.111.115 1.652-.105.541-.221 1.324-1.059 2.238-2.758q.52-1.185.473-1.282" />
            </svg>
            Download
          </a>
          <a
            href={GITHUB_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="btn-secondary px-5 py-1.5 border border-neutral-300 text-sm rounded-full inline-flex items-center justify-center gap-2"
          >
            GitHub
          </a>
        </div>

        {/* Footer */}
        <footer className="text-xs text-neutral-500 mt-16">
          Made by{" "}
          <a href="mailto:contact@pavloscompany.com" className="underline">
            Pavlos RSA
          </a>
        </footer>
      </div>
    </main>
  );
}
