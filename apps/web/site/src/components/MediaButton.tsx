'use client';

import React, { useState } from 'react';

type IconType = 'play' | 'pause' | 'skipBack' | 'skipForward';

interface MediaButtonProps {
  icon: IconType;
  onClick?: () => void;
  size?: number;
}

const IconSVG = ({ icon, size = 20 }: { icon: IconType; size?: number }) => {
  const iconSize = size;
  const commonProps = {
    width: iconSize,
    height: iconSize,
    viewBox: "0 0 24 24",
    fill: "none",
    xmlns: "http://www.w3.org/2000/svg"
  };
  
  switch (icon) {
    case 'play':
      return (
        <svg {...commonProps}>
          <path d="M7 4V20L18 12L7 4Z" fill="#000000" />
        </svg>
      );
    case 'pause':
      return (
        <svg {...commonProps}>
          <rect x="6" y="4" width="4" height="16" fill="#000000" />
          <rect x="14" y="4" width="4" height="16" fill="#000000" />
        </svg>
      );
    case 'skipBack':
      return (
        <svg {...commonProps}>
          <path d="M11 20L6 12L11 4V20Z" fill="#000000" />
          <rect x="16" y="4" width="2" height="16" fill="#000000" />
        </svg>
      );
    case 'skipForward':
      return (
        <svg {...commonProps}>
          <rect x="6" y="4" width="2" height="16" fill="#000000" />
          <path d="M13 20L18 12L13 4V20Z" fill="#000000" />
        </svg>
      );
    default:
      return null;
  }
};

export default function MediaButton({ icon, onClick, size = 48 }: MediaButtonProps) {
  const [isPressed, setIsPressed] = useState(false);

  const handleMouseDown = () => {
    setIsPressed(true);
  };

  const handleMouseUp = () => {
    setIsPressed(false);
    onClick?.();
  };

  return (
    <button
      className="relative rounded-lg cursor-pointer active:outline-none focus:outline-none overflow-hidden"
      style={{
        width: `${size}px`,
        height: `${size}px`,
        backgroundColor: '#D5D4D0',
        boxShadow: isPressed
          ? `
              inset 0 2px 4px rgba(0, 0, 0, 0.2),
              inset 0 1px 0 rgba(0, 0, 0, 0.15),
              0 1px 2px rgba(0, 0, 0, 0.1)
            `
          : `
              0 4px 8px rgba(0, 0, 0, 0.2),
              0 2px 4px rgba(0, 0, 0, 0.15),
              0 1px 2px rgba(0, 0, 0, 0.1),
              inset 0 1px 0 rgba(255, 255, 255, 0.3)
            `,
        transform: isPressed ? 'scale(0.95)' : 'scale(1)',
        transition: 'transform 0.1s, box-shadow 0.1s',
      }}
      onMouseDown={handleMouseDown}
      onMouseUp={handleMouseUp}
      onMouseLeave={() => setIsPressed(false)}
    >
      {/* Grain texture */}
      <div
        className="absolute inset-0 opacity-[0.3] mix-blend-overlay pointer-events-none"
        style={{
          backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 400 400' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='1.2' numOctaves='5' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)'/%3E%3C/svg%3E")`,
          backgroundSize: '100px 100px',
        }}
      />
      
      {/* Top highlight for raised effect */}
      <div
        className="absolute rounded-lg pointer-events-none"
        style={{
          width: `${size * 0.7}px`,
          height: `${size * 0.4}px`,
          left: '50%',
          top: '15%',
          transform: 'translateX(-50%)',
          background: 'radial-gradient(ellipse, rgba(255, 255, 255, 0.4), transparent)',
        }}
      />
      
      {/* Icon */}
      <div className="relative z-10 flex items-center justify-center h-full pointer-events-none">
        <IconSVG icon={icon} size={20} />
      </div>
    </button>
  );
}
