import { memo } from "react";
import Image from "next/image";

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
      <Image
        src="/manilafolder.avif"
        alt="Manila folder"
        fill
        className="object-cover"
        priority
        quality={85}
        sizes="(max-width: 768px) 100vw, 600px"
      />
    </div>
  );
});
