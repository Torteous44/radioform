import React from 'react';

interface ScrewProps {
  size?: number;
  className?: string;
}

export default function Screw({ size = 40, className = '' }: ScrewProps) {
  return (
    <div
      className={`relative rounded-full ${className}`}
      style={{
        width: `${size}px`,
        height: `${size}px`,
        background: 'radial-gradient(circle at 30% 30%, #C3C2C8,rgb(218, 218, 218),rgb(223, 223, 224))',
        border: '0.5px solid rgba(101, 101, 101, 0.3)',
        boxShadow: `
          inset 0 2px 4px rgba(255, 255, 255, 0.2),
          inset 0 -2px 4px rgba(0, 0, 0, 0.3),
          inset 2px 0 4px rgba(255, 255, 255, 0.15),
          inset -2px 0 4px rgba(0, 0, 0, 0.3),
          0 1px 2px rgba(135, 135, 135, 0.2)
        `,
      }}
    >
      {/* Noise texture overlay */}
      <div
        className="absolute inset-0 rounded-full opacity-[0.4] mix-blend-overlay"
        style={{
          backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 400 400' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='2.5' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)'/%3E%3C/svg%3E")`,
          backgroundSize: '40px 40px',
        }}
      />
      
      {/* Center hole with deep inset shadow - hexagon shape */}
      <div
        className="absolute"
        style={{
          width: `${size * 0.35}px`,
          height: `${size * 0.35}px`,
          left: '50%',
          top: '50%',
          transform: 'translate(-50%, -50%)',
          background: 'radial-gradient(circle at 30% 30%, #1a1a1a, #000000)',
          clipPath: 'polygon(50% 0%, 100% 25%, 100% 75%, 50% 100%, 0% 75%, 0% 25%)',
          boxShadow: `
            inset 0 2px 4px rgba(0, 0, 0, 0.9),
            inset 0 -2px 4px rgba(0, 0, 0, 0.9),
            inset 2px 0 4px rgba(0, 0, 0, 0.9),
            inset -2px 0 4px rgba(0, 0, 0, 0.9),
            inset 0 1px 2px rgba(0, 0, 0, 1)
          `,
        }}
      />
      
      {/* Subtle highlight on top */}
      <div
        className="absolute rounded-full pointer-events-none"
        style={{
          width: `${size * 0.5}px`,
          height: `${size * 0.3}px`,
          left: '50%',
          top: '20%',
          transform: 'translateX(-50%)',
          background: 'radial-gradient(ellipse, rgba(255, 255, 255, 0.15), transparent)',
        }}
      />
    </div>
  );
}

