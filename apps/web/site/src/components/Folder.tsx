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
}
