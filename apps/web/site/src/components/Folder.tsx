"use client";

import { memo } from "react";

interface FolderProps {
  className?: string;
  onClick?: () => void;
  style?: React.CSSProperties;
}

export default memo(function Folder({ className = "", onClick, style }: FolderProps) {
  return (
    <div
      className={`relative w-full h-full ${onClick ? "cursor-pointer" : ""} ${className}`}
      onClick={onClick}
      style={style}
    >
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src="/manilafolder.avif"
        alt="Manila folder"
        className="block w-full h-full"
      />
    </div>
  );
});
