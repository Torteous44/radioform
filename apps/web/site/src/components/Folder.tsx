"use client";

interface FolderProps {
  className?: string;
  onClick?: () => void;
  style?: React.CSSProperties;
}

export default function Folder({ className = "", onClick, style }: FolderProps) {
  return (
    <div
      className={`relative w-[600px] h-[724px] ${onClick ? "cursor-pointer" : ""} ${className}`}
      onClick={onClick}
      style={{
        ...style,
        filter: `
          drop-shadow(0px 1px 1px rgba(0,0,0,0.15))
          drop-shadow(0px 2px 2px rgba(0,0,0,0.12))
          drop-shadow(0px 4px 4px rgba(0,0,0,0.10))
          drop-shadow(0px 8px 8px rgba(0,0,0,0.08))
          drop-shadow(0px 16px 16px rgba(0,0,0,0.05))
          drop-shadow(-2px 0px 4px rgba(0,0,0,0.03))
        `,
      }}
    >
      {/* Base: Folder SVG background */}
      <img
        src="/folder.svg"
        alt="Manila folder"
        className="absolute top-0 left-0 w-full h-full"
      />

      {/* Layer 1: Paper fiber texture */}
      <div
        className="absolute top-0 left-0 w-full h-full pointer-events-none z-[1]"
        style={{
          backgroundImage: "url('/manilatexture.png')",
          backgroundSize: "300px 200px",
          backgroundRepeat: "repeat",
          opacity: 0.35,
          mixBlendMode: "multiply",
          maskImage: "url('/folder.svg')",
          maskSize: "100% 100%",
          WebkitMaskImage: "url('/folder.svg')",
          WebkitMaskSize: "100% 100%",
        }}
      />

      {/* Layer 2: Aging/discoloration gradients */}
      <div
        className="absolute top-0 left-0 w-full h-full pointer-events-none z-[2]"
        style={{
          background: `
            radial-gradient(
              ellipse 120% 100% at 50% 0%,
              transparent 40%,
              rgba(139, 90, 43, 0.08) 70%,
              rgba(101, 67, 33, 0.12) 100%
            ),
            radial-gradient(
              circle at 0% 100%,
              rgba(160, 120, 60, 0.06) 0%,
              transparent 40%
            ),
            radial-gradient(
              circle at 100% 100%,
              rgba(160, 120, 60, 0.06) 0%,
              transparent 40%
            )
          `,
          maskImage: "url('/folder.svg')",
          maskSize: "100% 100%",
          WebkitMaskImage: "url('/folder.svg')",
          WebkitMaskSize: "100% 100%",
        }}
      />

      {/* Layer 3: Corner wear vignettes */}
      <div
        className="absolute top-0 left-0 w-full h-full pointer-events-none z-[3]"
        style={{
          background: `
            radial-gradient(
              ellipse 80px 80px at 10px 10px,
              rgba(255, 240, 220, 0.4) 0%,
              rgba(255, 240, 220, 0.15) 40%,
              transparent 70%
            ),
            radial-gradient(
              ellipse 60px 60px at calc(100% - 15px) 15px,
              rgba(255, 235, 210, 0.25) 0%,
              transparent 60%
            ),
            radial-gradient(
              ellipse 100px 100px at 8px calc(100% - 8px),
              rgba(255, 245, 225, 0.35) 0%,
              rgba(200, 160, 100, 0.1) 50%,
              transparent 80%
            ),
            radial-gradient(
              ellipse 120px 120px at calc(100% - 5px) calc(100% - 5px),
              rgba(255, 248, 230, 0.45) 0%,
              rgba(220, 180, 120, 0.2) 40%,
              transparent 75%
            )
          `,
          maskImage: "url('/folder.svg')",
          maskSize: "100% 100%",
          WebkitMaskImage: "url('/folder.svg')",
          WebkitMaskSize: "100% 100%",
        }}
      />

      {/* Layer 4: Ambient occlusion / edge darkening */}
      <div
        className="absolute top-0 left-0 w-full h-full pointer-events-none z-[4]"
        style={{
          background: `
            radial-gradient(
              ellipse 200px 60px at 300px 49px,
              rgba(0, 0, 0, 0.12) 0%,
              rgba(0, 0, 0, 0.05) 40%,
              transparent 70%
            ),
            linear-gradient(
              90deg,
              rgba(0, 0, 0, 0.06) 0%,
              transparent 3%
            ),
            linear-gradient(
              270deg,
              rgba(0, 0, 0, 0.04) 0%,
              transparent 2%
            ),
            linear-gradient(
              0deg,
              rgba(0, 0, 0, 0.05) 0%,
              transparent 2%
            )
          `,
          maskImage: "url('/folder.svg')",
          maskSize: "100% 100%",
          WebkitMaskImage: "url('/folder.svg')",
          WebkitMaskSize: "100% 100%",
        }}
      />

      {/* Layer 5: Primary lighting gradient */}
      <div
        className="absolute top-0 left-0 w-full h-full pointer-events-none z-[5]"
        style={{
          background: `
            linear-gradient(
              135deg,
              rgba(255, 255, 255, 0.18) 0%,
              rgba(255, 255, 255, 0.08) 15%,
              rgba(255, 255, 255, 0.02) 35%,
              transparent 50%,
              rgba(0, 0, 0, 0.02) 70%,
              rgba(0, 0, 0, 0.06) 85%,
              rgba(0, 0, 0, 0.1) 100%
            )
          `,
          maskImage: "url('/folder.svg')",
          maskSize: "100% 100%",
          WebkitMaskImage: "url('/folder.svg')",
          WebkitMaskSize: "100% 100%",
        }}
      />

      {/* Layer 6: Edge highlights / rim lighting */}
      <div
        className="absolute top-0 left-0 w-full h-full pointer-events-none z-[6]"
        style={{
          boxShadow: `
            inset 3px 3px 0px rgba(255, 255, 255, 0.25),
            inset 1px 1px 0px rgba(255, 255, 255, 0.4),
            inset -2px -2px 0px rgba(0, 0, 0, 0.08),
            inset -1px -1px 0px rgba(0, 0, 0, 0.04),
            inset 0 0 20px rgba(0, 0, 0, 0.03)
          `,
          maskImage: "url('/folder.svg')",
          maskSize: "100% 100%",
          WebkitMaskImage: "url('/folder.svg')",
          WebkitMaskSize: "100% 100%",
        }}
      />

      {/* Layer 7: Specular highlight */}
      <div
        className="absolute top-0 left-0 w-full h-full pointer-events-none z-[7]"
        style={{
          background: `
            radial-gradient(
              ellipse 200px 150px at 150px 200px,
              rgba(255, 255, 255, 0.12) 0%,
              rgba(255, 255, 255, 0.04) 40%,
              transparent 70%
            )
          `,
          maskImage: "url('/folder.svg')",
          maskSize: "100% 100%",
          WebkitMaskImage: "url('/folder.svg')",
          WebkitMaskSize: "100% 100%",
        }}
      />

      {/* Layer 8: Fine noise/grain overlay */}
      <div
        className="absolute top-0 left-0 w-full h-full pointer-events-none z-[8]"
        style={{
          backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 400 400' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='1.2' numOctaves='5' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)'/%3E%3C/svg%3E")`,
          opacity: 0.06,
          mixBlendMode: "overlay",
          maskImage: "url('/folder.svg')",
          maskSize: "100% 100%",
          WebkitMaskImage: "url('/folder.svg')",
          WebkitMaskSize: "100% 100%",
        }}
      />

      {/* Layer 9: Text content */}
      <div className="absolute top-0 left-0 w-full h-full pt-[120px] px-[50px] pb-[40px] flex flex-col font-[family-name:var(--font-special-elite)] tracking-[0.05em] text-[#2a2318] pointer-events-none z-[9]">
        <p className="text-center text-[14px] mb-1">INTRODUCING</p>
        <h1 className="text-center text-[42px] font-normal m-0 mb-1">"RADIOFORM"</h1>
        <p className="text-center text-[14px] mb-1">BY</p>
        <p className="text-center text-[16px] mb-8">THE PAVLOS COMPANY RSA</p>

        <hr className="border border-t-0 border-[#2a2318]" />

        <p className="text-center text-[18px] mt-4 mb-3">AN EQ MACOS APP THAT "JUST WORKS"</p>

        <hr className="border border-t-0 border-[#2a2318] mb-2" />

        <div className="grid grid-cols-3 text-[12px] mt-8 px-[10px]">
          <span className="text-left">DELIVERED TO:</span>
          <span className="text-center">NAME</span>
          <span className="text-right">ADDRESS</span>
        </div>
        <div className="flex flex-col gap-6 mt-4 px-[10px]">
          <div className="w-full border-b border-dotted border-[#2a2318]" />
          <div className="w-full border-b border-dotted border-[#2a2318]" />
          <div className="w-full border-b border-dotted border-[#2a2318]" />
        </div>

        <p className="text-[12px] mt-8 px-[10px]">MAILED FROM:</p>
        <div className="flex flex-col gap-6 mt-4 px-[10px]">
          <div className="w-full border-b border-dotted border-[#2a2318]" />
          <div className="w-full border-b border-dotted border-[#2a2318]" />
          <div className="w-full border-b border-dotted border-[#2a2318]" />
        </div>
      </div>
    </div>
  );
}
