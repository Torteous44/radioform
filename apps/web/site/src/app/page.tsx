"use client";

import { useState, useEffect } from "react";
import Image from "next/image";

function useIsMobile() {
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    const checkMobile = () => {
      setIsMobile(window.innerWidth < 768);
    };
    checkMobile();
    window.addEventListener("resize", checkMobile);
    return () => window.removeEventListener("resize", checkMobile);
  }, []);

  return isMobile;
}

const DOWNLOAD_URL =
  "https://github.com/Torteous44/radioform/releases/latest/download/Radioform.dmg";
const GITHUB_URL = "https://github.com/Torteous44/radioform";

const VIDEOS = {
  menubar:
    "https://res.cloudinary.com/dwgn0lwli/video/upload/v1767614903/mb_1_mqccrc.mp4",
  presets:
    "https://res.cloudinary.com/dwgn0lwli/video/upload/v1767614904/mb-preset_1_y7vonk.mp4",
  custom:
    "https://res.cloudinary.com/dwgn0lwli/video/upload/v1767614904/mb-custom_1_psrdyb.mp4",
};

interface HoverState {
  visible: boolean;
  src: string;
  x: number;
  y: number;
}

interface FAQItem {
  question: string;
  answer: React.ReactNode;
}

function FAQ({ question, answer }: FAQItem) {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <div className="border-b border-neutral-200">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="w-full py-4 flex justify-between items-center text-left text-sm font-medium"
      >
        {question}
        <span
          className="text-neutral-400 transition-transform duration-200"
          style={{ transform: isOpen ? "rotate(45deg)" : "rotate(0deg)" }}
        >
          +
        </span>
      </button>
      <div
        className="grid transition-all duration-300 ease-out"
        style={{
          gridTemplateRows: isOpen ? "1fr" : "0fr",
          opacity: isOpen ? 1 : 0,
        }}
      >
        <div className="overflow-hidden">
          <div className="text-sm text-neutral-600 leading-relaxed mb-6">
            {answer}
          </div>
        </div>
      </div>
    </div>
  );
}

function HoverTooltip({ src, x, y, visible }: HoverState) {
  return (
    <div
      className="fixed z-50 pointer-events-none transition-all duration-200 ease-out"
      style={{
        left: `${x}px`,
        top: `${y}px`,
        transform: "translate(16px, -50%)",
        opacity: visible ? 1 : 0,
        scale: visible ? "1" : "0.95",
      }}
    >
      <div className="bg-white border border-neutral-200 rounded overflow-hidden shadow-lg w-[200px] h-[200px]">
        {src && (
          <video
            key={src}
            src={src}
            autoPlay
            loop
            muted
            playsInline
            className="w-full h-full object-cover"
          />
        )}
      </div>
    </div>
  );
}

export default function Home() {
  const isMobile = useIsMobile();
  const [hoverState, setHoverState] = useState<HoverState>({
    visible: false,
    src: "",
    x: 0,
    y: 0,
  });

  const handleHover = (src: string) => {
    setHoverState((prev) => ({ ...prev, visible: true, src }));
  };

  const handleMove = (e: React.MouseEvent) => {
    setHoverState((prev) => ({
      ...prev,
      x: e.clientX,
      y: e.clientY,
    }));
  };

  const handleLeave = () => {
    setHoverState((prev) => ({ ...prev, visible: false }));
  };

  // Preload videos
  useEffect(() => {
    Object.values(VIDEOS).forEach((url) => {
      const video = document.createElement("video");
      video.src = url;
      video.preload = "auto";
      video.muted = true;
    });
  }, []);

  return (
    <main className="min-h-screen px-4 sm:px-6 py-12 sm:py-16">
      {!isMobile && <HoverTooltip {...hoverState} />}
      <div className="max-w-md mx-auto">
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
            Radioform is a macOS native equalizer that lets you shape your sound
            system-wide.
          </p>
          <p>
            It tucks into your{" "}
            <span
              className={isMobile ? "" : "underline cursor-pointer"}
              onMouseEnter={
                isMobile ? undefined : () => handleHover(VIDEOS.menubar)
              }
              onMouseMove={isMobile ? undefined : handleMove}
              onMouseLeave={isMobile ? undefined : handleLeave}
            >
              menubar
            </span>{" "}
            and stays out of your way. Pick from{" "}
            <span
              className={isMobile ? "" : "underline cursor-pointer"}
              onMouseEnter={
                isMobile ? undefined : () => handleHover(VIDEOS.presets)
              }
              onMouseMove={isMobile ? undefined : handleMove}
              onMouseLeave={isMobile ? undefined : handleLeave}
            >
              ready-made presets
            </span>{" "}
            or{" "}
            <span
              className={isMobile ? "" : "underline cursor-pointer"}
              onMouseEnter={
                isMobile ? undefined : () => handleHover(VIDEOS.custom)
              }
              onMouseMove={isMobile ? undefined : handleMove}
              onMouseLeave={isMobile ? undefined : handleLeave}
            >
              craft your own EQ curves
            </span>{" "}
            for different gear—your studio monitors, your AirPods, your living
            room setup. One app, every scenario.
          </p>
          <p>Built with C++ and Swift. Open source and free.</p>
        </div>

        {/* CTA Buttons */}
        <div className="flex flex-col sm:flex-row gap-3 mb-10">
          {isMobile ? (
            <button
              disabled
              className="px-5 py-2.5 bg-neutral-300 text-neutral-500 text-sm rounded-full inline-flex items-center justify-center gap-2 cursor-not-allowed"
              style={{
                backgroundImage:
                  "radial-gradient(75% 50% at 50% 0%, rgba(255,255,255,0.3) 12%, transparent), radial-gradient(75% 50% at 50% 85%, rgba(255,255,255,0.15), transparent)",
                boxShadow:
                  "inset 0 0 2px 1px rgba(255, 255, 255, 0.2), 0 1px 4px 1px rgba(0, 0, 0, 0.1)",
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
          ) : (
            <a
              href={DOWNLOAD_URL}
              className="btn-primary px-4 py-1 text-white text-sm rounded-full inline-flex items-center justify-center gap-2  "
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
          )}
          <a
            href={GITHUB_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="btn-secondary px-5 py-1.5 border border-neutral-300 text-sm rounded-full text-center"
          >
            GitHub
          </a>
        </div>

        {/* FAQs */}
        <div className="border-t border-neutral-200">
          <FAQ
            question="How do I get started?"
            answer={
              <div className="space-y-3 ">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-8 p-1 sm:gap-4 sm:p-0">
                  {[
                    {
                      img: "/instructions/frame1.avif",
                      text: "1. Download & install",
                    },
                    {
                      img: "/instructions/frame2.avif",
                      text: "2. Select audio device",
                    },
                    {
                      img: "/instructions/frame3.avif",
                      text: "3. Choose a preset or design your own",
                    },
                    { img: "/instructions/frame4.avif", text: "4. Enjoy" },
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
