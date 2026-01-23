import Image from "next/image";

const DOWNLOAD_URL =
  "https://github.com/Torteous44/radioform/releases/latest/download/Radioform.dmg";
const GITHUB_URL = "https://github.com/Torteous44/radioform";

export default function Home() {
  return (
    <main className="min-h-screen px-6 py-16">
      <div className="max-w-xs mx-auto">
        {/* Header */}
        <h1
          className="text-3xl font-normal mb-6"
          style={{ fontFamily: "var(--font-serif)" }}
        >
          Radioform
        </h1>

        {/* Copy */}
        <div className="text-sm leading-relaxed space-y-4 mb-8">
          <p>
            You've got the headphones. You've got the speakers. But macOS still
            outputs the same flat, unoptimized audio it always has. Radioform is
            a macOS native equalizer that finally lets you shape your sound
            system-wide.
          </p>
          <p>
            It tucks into your menubar and stays out of your way. Pick from
            ready-made presets or craft your own EQ curves for different
            gear—your studio monitors, your AirPods, your living room setup. One
            app, every scenario.
          </p>
          <p>
            Built in Swift, fully open source, and completely free. No bloat, no
            secrets, no price tag.
          </p>
        </div>

        {/* CTA Buttons */}
        <div className="flex gap-3 mb-12">
          <a
            href={DOWNLOAD_URL}
            className="px-5 py-2.5 bg-black text-white text-sm rounded-full hover:bg-neutral-800 transition-colors inline-flex items-center gap-2"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="14"
              height="14"
              fill="currentColor"
              viewBox="0 0 16 16"
            >
              <path d="M11.182.008C11.148-.03 9.923.023 8.857 1.18c-1.066 1.156-.902 2.482-.878 2.516s1.52.087 2.475-1.258.762-2.391.728-2.43m3.314 11.733c-.048-.096-2.325-1.234-2.113-3.422s1.675-2.789 1.698-2.854-.597-.79-1.254-1.157a3.7 3.7 0 0 0-1.563-.434c-.108-.003-.483-.095-1.254.116-.508.139-1.653.589-1.968.607-.316.018-1.256-.522-2.267-.665-.647-.125-1.333.131-1.824.328-.49.196-1.422.754-2.074 2.237-.652 1.482-.311 3.83-.067 4.56s.625 1.924 1.273 2.796c.576.984 1.34 1.667 1.659 1.899s1.219.386 1.843.067c.502-.308 1.408-.485 1.766-.472.357.013 1.061.154 1.782.539.571.197 1.111.115 1.652-.105.541-.221 1.324-1.059 2.238-2.758q.52-1.185.473-1.282" />
            </svg>
            Download
          </a>
          <a
            href={GITHUB_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="px-5 py-2.5 border border-black text-sm rounded-full hover:bg-black hover:text-white transition-colors"
          >
            GitHub
          </a>
        </div>

        {/* Instructions */}
        <h2
          className="text-lg font-normal mb-6"
          style={{ fontFamily: "var(--font-serif)" }}
        >
          Instructions for enjoyment
        </h2>
        <div className="grid grid-cols-2 gap-4">
          {[
            { img: "/instructions/frame1.avif", text: "Download & install" },
            { img: "/instructions/frame2.avif", text: "Select audio device" },
            { img: "/instructions/frame3.avif", text: "Choose preset or custom EQ" },
            { img: "/instructions/frame4.avif", text: "Enjoy" },
          ].map((step, i) => (
            <div key={i}>
              <Image
                src={step.img}
                alt={`Step ${i + 1}`}
                width={200}
                height={200}
                className="w-full aspect-square object-cover rounded mb-2"
              />
              <p className="text-xs">{step.text}</p>
            </div>
          ))}
        </div>

        {/* Footer */}
        <p className="text-xs text-neutral-500 mt-16">
          Made by Pavlos Company RSA
        </p>
      </div>
    </main>
  );
}
