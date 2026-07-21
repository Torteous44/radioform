import Image from "next/image";
import FAQ from "./components/FAQ";
import FaqStep from "./components/FaqStep";

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
        "10-band parametric equalizer (32 Hz to 16 kHz)",
        "Built-in presets for Electronic, Acoustic, Classical, Hip-Hop, Pop, R&B, Rock, Flat",
        "Built-in limiter and preamp",
        "No latency you can hear",
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
            text: "Radioform makes a virtual audio device that sits between your apps and your speakers. Everything you play runs through the EQ engine, then goes on to your real output. No delay you can hear. Under 1% CPU.",
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
            text: "Yes. It's GPLv3. Fully open source. No cost, no subscription, no data collection. You can read every line of code, build it yourself, or fork it.",
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

async function getStarCount(): Promise<number | null> {
  try {
    const res = await fetch(
      "https://api.github.com/repos/Torteous44/radioform",
      {
        headers: { Accept: "application/vnd.github+json" },
        next: { revalidate: 3600 },
      },
    );
    if (!res.ok) return null;
    const data = await res.json();
    return typeof data.stargazers_count === "number"
      ? data.stargazers_count
      : null;
  } catch {
    return null;
  }
}

export default async function Home() {
  const stars = await getStarCount();
  return (
    <main className="min-h-screen px-4 sm:px-6 pt-[13vh] pb-12 sm:pb-16">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <div className="max-w-[26rem] mx-auto">
        {/* Hero */}
        <div className="relative w-full max-[479px]:hidden aspect-[1000/200] scale-x-[1.13]">
          <Image
            src="/painting1_baked.avif"
            alt=""
            fill
            priority
            sizes="(min-width: 768px) 512px, 100vw"
            className="object-contain"
          />
        </div>

        <StretchedTitle />
        <h1 className="sr-only">
          Radioform: A free, open-source macOS equalizer
        </h1>

        {/* Copy */}
        <div className="text-sm leading-relaxed space-y-4 mb-8">
          <p>
            Radioform is a free, open source equalizer for your Mac. It quietly
            shapes the sound of everything you play.
          </p>
          <p>
            It tucks into your menu bar and stays out of the way. Pick one of
            the presets, or build your own curve and save it for later.
          </p>
          <p>
            Built with C++ and Swift. Read more{" "}
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
            <span className="-translate-y-px">Download</span>
          </a>
          <a
            href={GITHUB_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="btn-secondary rounded-none px-5 py-0 border border-neutral-300 text-sm rounded-full inline-flex items-center justify-center gap-1"
          >
            {stars !== null ? (
              <>
                <span className="-translate-y-px">GitHub</span>
                <span className="inline-flex items-center gap-0.5 text-[10px] text-neutral-500">
                  ({stars.toLocaleString("en-US")}
                  <svg
                    aria-hidden
                    width="11"
                    height="11"
                    viewBox="0 0 24 24"
                    fill="currentColor"
                    className="block translate-y-[0.5px]"
                  >
                    <path d="M12 17.27 18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z" />
                  </svg>
                  )
                </span>
              </>
            ) : (
              <span className="-translate-y-px">GitHub</span>
            )}
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
              <FaqStep
                src="/instructions/faq-getting-started.png"
                width={843}
                height={685}
                alt="Download Radioform, pick the Radioform output, open the EQ, and enjoy."
              >
                <p>
                  Download Radioform and drag it into your Applications folder.
                  Open it once and it sits in your menu bar.
                </p>
                <p>
                  In your Sound settings, pick the Radioform output that matches
                  your speakers or your headphones. Now your Mac plays through
                  it.
                </p>
                <p>
                  Open the menu bar icon and the EQ is there. Start from a
                  preset, or pull the sliders until it sounds right.
                  Double-click a band for advanced settings. Enjoy.
                </p>
              </FaqStep>
            }
          />
          <FAQ
            question="How does it work?"
            answer={
              <FaqStep
                src="/instructions/faq-how-it-works.png"
                width={866}
                height={397}
                alt="Your apps' sound runs through Radioform to your speakers with zero delay and under 1% CPU."
              >
                <p>
                  Radioform makes a virtual audio device that sits between your
                  apps and your speakers. Everything you play runs through the
                  EQ engine, then goes on to your real output. No delay. Under
                  1% CPU usage.
                </p>
              </FaqStep>
            }
          />
          <FAQ
            question="What's under the hood?"
            answer={
              <FaqStep
                src="/instructions/faq-under-the-hood.png"
                width={1257}
                height={471}
                alt="The C++ driver, the Swift host, and the menu bar app, all wired into macOS CoreAudio."
              >
                <p>
                  The audio engine is C++ with cascaded biquad filters. The
                  virtual device uses Apple&apos;s Audio Server Plugin
                  (libASPL). The menu bar app is native Swift and SwiftUI. They
                  talk through a clean C API and shared memory, so the audio
                  stays real-time safe.
                </p>
              </FaqStep>
            }
          />
          <FAQ
            question="Is it really free?"
            answer={
              <FaqStep
                src="/instructions/faq-free.png"
                width={664}
                height={287}
                alt="Radioform is free and open source under GPLv3."
              >
                <p>
                  Yes. It&apos;s GPLv3. Fully open source. No cost, no
                  subscription, no data collection. You can read every line of
                  code, build it yourself, or fork it.
                </p>
              </FaqStep>
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
