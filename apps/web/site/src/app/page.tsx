import Image from "next/image";
import FAQ from "./components/FAQ";

const jsonLd = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "SoftwareApplication",
      name: "Radioform",
      description:
        "A free, open-source native macOS equalizer that lives in your menu bar and shapes your sound system-wide.",
      applicationCategory: "MultimediaApplication",
      operatingSystem: "macOS 13.0+",
      url: "https://radioform.app",
      downloadUrl:
        "https://github.com/Torteous44/radioform/releases/latest/download/Radioform.dmg",
      softwareVersion: "latest",
      license: "https://www.gnu.org/licenses/gpl-3.0.html",
      isAccessibleForFree: true,
      offers: {
        "@type": "Offer",
        price: "0",
        priceCurrency: "USD",
      },
      featureList: [
        "10-band fully parametric equalizer (20 Hz to 20 kHz)",
        "Built-in presets for Electronic, Acoustic, Classical, Hip-Hop, Pop, R&B, Rock, Flat",
        "Built-in limiter and preamp",
        "Zero added latency",
        "Sub-1% CPU usage",
        "Native Swift/SwiftUI menu bar app",
        "C++ audio engine with cascaded biquad filters",
        "Apple Silicon and Intel support",
      ],
      screenshot: "https://radioform.app/demo/radioform.png",
      author: {
        "@type": "Person",
        name: "Pavlos RSA",
        email: "contact@pavloscompany.com",
      },
      codeRepository: "https://github.com/Torteous44/radioform",
    },
    {
      "@type": "FAQPage",
      mainEntity: [
        {
          "@type": "Question",
          name: "How do I get started with Radioform?",
          acceptedAnswer: {
            "@type": "Answer",
            text: "Download and install Radioform, then select an audio device, choose a preset or create your own EQ curve, and enjoy your customized sound.",
          },
        },
        {
          "@type": "Question",
          name: "How does Radioform work?",
          acceptedAnswer: {
            "@type": "Answer",
            text: "Radioform creates a virtual audio device that sits between your apps and your speakers. All system audio passes through a high-quality DSP engine where it gets shaped by your EQ settings in real-time—then continues to your actual output device. Zero added latency, sub-1% CPU usage.",
          },
        },
        {
          "@type": "Question",
          name: "What technology is Radioform built with?",
          acceptedAnswer: {
            "@type": "Answer",
            text: "The audio engine is written in C++ using cascaded biquad filters for precise EQ control. The virtual audio device uses Apple's Audio Server Plugin (libASPL) framework. The menu bar app is native Swift/SwiftUI. Everything communicates through a clean C API and shared memory for real-time safety.",
          },
        },
        {
          "@type": "Question",
          name: "Is Radioform really free?",
          acceptedAnswer: {
            "@type": "Answer",
            text: "Yes. Radioform is released under the GPLv3 license—fully open source, no hidden costs, no subscriptions, no data collection. You can read every line of code, build it yourself, or fork it for your own projects.",
          },
        },
      ],
    },
    {
      "@type": "WebSite",
      url: "https://radioform.app",
      name: "Radioform",
      description:
        "Radioform is an open source macOS EQ app that lives in your menubar.",
    },
  ],
};

function StretchedTitle() {
  return (
    <div className="mb-6 w-full">
      <svg
        className="w-full h-12"
        viewBox="0 0 600 48"
        preserveAspectRatio="none"
        role="img"
        aria-label="Radioform"
      >
        <text
          x="0"
          y="36"
          textLength="600"
          lengthAdjust="spacingAndGlyphs"
          style={{ fontFamily: "var(--font-serif)", fontSize: "36px" }}
          fill="currentColor"
        >
          Radioform
        </text>
      </svg>
    </div>
  );
}

const DOWNLOAD_URL =
  "https://github.com/Torteous44/radioform/releases/latest/download/Radioform.dmg";
const GITHUB_URL = "https://github.com/Torteous44/radioform";

const FAQ_IMAGES = [
  "/instructions/frame1.avif",
  "/instructions/frame2.avif",
  "/instructions/frame3.avif",
  "/instructions/frame4.avif",
];

interface FAQItem {
  question: string;
  answer: React.ReactNode;
}

export default function Home() {
  return (
    <main className="min-h-screen px-4 sm:px-6 py-12 sm:py-16">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <div className="max-w-md mx-auto">
        {/* Hero */}
        <div className="w-full overflow-hidden hidden min-[480px]:block">
          <Image
            src="/painting1_baked.avif"
            alt=""
            width={800}
            height={330}
            priority
            sizes="(min-width: 768px) 512px, 100vw"
            className="w-full object-cover scale-x-[1.1]"
          />
        </div>

        <StretchedTitle />
        <h1 className="sr-only">
          Radioform: A free, open-source macOS equalizer
        </h1>

        {/* Copy */}
        <div className="text-sm leading-relaxed space-y-4 mb-8">
          <p>
            Radioform is a free, open-source macOS equalizer that lets you shape
            your sound system-wide — with fully parametric per-band control.
          </p>
          <p>
            It tucks into your menubar and stays out of your way. Pick a preset
            or craft your own EQ curves for different gear.
          </p>
          <p>
            Created with C++ and Swift. Learn more{" "}
            <a href="/about" className="underline">
              here
            </a>
            .
          </p>
        </div>

        {/* CTA Buttons */}
        <div className="grid grid-cols-2 gap-3 mb-10">
          <button
            disabled
            className="md:hidden px-5 py-1.5 bg-neutral-300 text-neutral-500 text-sm squircle inline-flex items-center justify-center gap-2 cursor-not-allowed"
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
            className="hidden md:inline-flex btn-primary rounded-none px-4 py-0 text-white text-sm rounded-full items-center justify-center gap-2"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="14"
              height="14"
              fill="currentColor"
              viewBox="0 0 16 16"
              className="mb-[1px] scale-[0.9]"
            >
              <path d="M11.182.008C11.148-.03 9.923.023 8.857 1.18c-1.066 1.156-.902 2.482-.878 2.516s1.52.087 2.475-1.258.762-2.391.728-2.43m3.314 11.733c-.048-.096-2.325-1.234-2.113-3.422s1.675-2.789 1.698-2.854-.597-.79-1.254-1.157a3.7 3.7 0 0 0-1.563-.434c-.108-.003-.483-.095-1.254.116-.508.139-1.653.589-1.968.607-.316.018-1.256-.522-2.267-.665-.647-.125-1.333.131-1.824.328-.49.196-1.422.754-2.074 2.237-.652 1.482-.311 3.83-.067 4.56s.625 1.924 1.273 2.796c.576.984 1.34 1.667 1.659 1.899s1.219.386 1.843.067c.502-.308 1.408-.485 1.766-.472.357.013 1.061.154 1.782.539.571.197 1.111.115 1.652-.105.541-.221 1.324-1.059 2.238-2.758q.52-1.185.473-1.282" />
            </svg>
            Download
          </a>
          <a
            href={GITHUB_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="btn-secondary rounded-none px-5 py-0 border border-neutral-300 text-sm rounded-full inline-flex items-center justify-center gap-2"
          >
            GitHub
          </a>
        </div>

        {/* FAQs */}
        <section
          aria-label="Frequently asked questions"
          className="border-t border-neutral-200"
        >
          <FAQ
            question="How do I get started?"
            answer={
              <div className="space-y-3 ">
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
                  {[
                    { img: FAQ_IMAGES[0], text: "First, Download & install" },
                    {
                      img: FAQ_IMAGES[1],
                      text: "Then, select an audio device",
                    },
                    {
                      img: FAQ_IMAGES[2],
                      text: "Select a preset or make your own",
                    },
                    { img: FAQ_IMAGES[3], text: "Finally, Enjoy" },
                  ].map((step, i) => (
                    <div key={i}>
                      <Image
                        src={step.img}
                        alt={`Step ${i + 1}`}
                        width={200}
                        height={200}
                        sizes="(min-width: 640px) 128px, 25vw"
                        className="w-full aspect-square object-cover rounded mb-2"
                      />
                      <p className="text-xs">{step.text}</p>
                    </div>
                  ))}
                </div>
              </div>
            }
          />
          <FAQ
            question="How does it work?"
            answer={
              <>
                Radioform creates a virtual audio device that sits between your
                apps and your speakers. All system audio passes through a
                high-quality DSP engine where it gets shaped by your EQ settings
                in real-time—then continues to your actual output device. Zero
                added latency, sub-1% CPU usage.
              </>
            }
          />
          <FAQ
            question="What's under the hood?"
            answer={
              <>
                The audio engine is written in C++ using cascaded biquad filters
                for precise EQ control. The virtual audio device uses
                Apple&apos;s Audio Server Plugin (libASPL) framework. The menu
                bar app is native Swift/SwiftUI. Everything talks through a
                clean C API and shared memory for real-time safety.
              </>
            }
          />
          <FAQ
            question="Is it really free?"
            answer={
              <>
                Yes. Radioform is released under the GPLv3 license—fully open
                source, no hidden costs, no subscriptions, no data collection.
                You can read every line of code, build it yourself, or fork it
                for your own projects.
              </>
            }
          />
        </section>

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
