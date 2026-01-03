"use client";

import Polaroid from "./Polaroid";

interface CardProps {
  className?: string;
  onClick?: () => void;
}

export default function Card({ className = "", onClick }: CardProps) {
  return (
    <div
      className={`relative w-full max-w-[480px] aspect-[1/1.414] p-6 ${onClick ? "cursor-pointer" : ""} ${className}`}
      onClick={onClick}
      style={{
        backgroundColor: "#ffffff",
        boxShadow: "0 2px 16px rgba(0,0,0,0.1)",
        fontFamily: '"Courier New", Courier, monospace',
        opacity: 1,
      }}
    >
      {/* Polaroid attached to top right */}
      <div className="absolute top-[-32px] right-[-48px] z-20">
        {/* Paperclip on top */}
        <img
          src="/paperclip.png"
          alt="Paperclip"
          className="absolute top-[12px] left-9/12 -translate-x-1/2 rotate-[-50deg] z-30 w-16 h-auto"
        />
        <Polaroid
          src="/radioform.png"
          alt="Attached photo"
          className="scale-[0.5] origin-top-right top-[36px] right-[36px] rotate-[5deg]"
        />
      </div>

      {/* Content */}
      <div className="relative z-10 h-full flex flex-col text-black">
        {/* MEMO Header */}
        <div className="text-left mb-4">
          <h1
            className="text-base font-bold tracking-widest mb-3"
            style={{ letterSpacing: "0.3em" }}
          >
            MEMO
          </h1>

          <div className="space-y-0 text-[12px]">
            <p>
              <span className="inline-block w-14">TO:</span>All Staff
            </p>
            <p>
              <span className="inline-block w-14">FROM:</span>Management
            </p>
            <p>
              <span className="inline-block w-14">DATE:</span>January 3, 2026
            </p>
            <p>
              <span className="inline-block w-14">RE:</span>Quarterly Update
            </p>
          </div>
        </div>

        {/* Divider line */}
        <div
          className="w-full mb-4"
          style={{
            borderTop: "1px solid #222",
          }}
        />

        {/* Body */}
        <div className="text-left space-y-3 text-[12px] leading-relaxed flex-1">
          <p>
            We know you've bought that new stereo system or headphones. We know
            you're excited. But it's time to take it to the next level. The level
            where your music starts to warm your ears like a hot shower. So let's
            make that happen.
          </p>

          <p>
            Introducing Radioform, the first EQ app that just works. It lives on
            your menubar, hidden away without interfering with your workflow. But
            it does interfere with how bad your music sounds, by making it sound
            so sweet like the Sirens from Odyssey.
          </p>

          <p>
            We built this project to be fully open sourced, so you know what you're
            getting into. Natively built in Swift, this app is a performant,
            lightweight way to enjoy your music the way it was meant to be.
            Seriously, give it a go.
          </p>

          <p>
            Take back control and learn what music can sound like once you really
            have got your hands dirty. Make your own custom EQ presets or use some
            of the pre-built ones. Optimize for your home stereo, your headphones,
            or even your MacBook. Radioform is for everyone.
          </p>

          <p className="inline-block">
            <button
              className="border-2 border-black bg-white px-4 py-2 text-[12px] font-bold tracking-wider hover:bg-black hover:text-white transition-colors duration-150"
              style={{
                fontFamily: '"Courier New", Courier, monospace',
                letterSpacing: "0.1em",
              }}
            >
              DOWNLOAD
            </button>
          </p>
        </div>

        {/* Logo at bottom - stamp style */}
        <div className="flex justify-end -mt-24">
          <img
            src="/pavlos.svg"
            alt="Logo"
            className="h-18 w-auto"
            style={{
              height: "124px",
              transform: "rotate(-16deg)",
            }}
          />
        </div>
      </div>
    </div>
  );
}
