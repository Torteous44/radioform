import Polaroid from "@/components/Polaroid";

export default function TestPolaroid() {
  return (
    <div className="h-screen w-screen paper-texture flex items-center justify-center">
      <Polaroid src="/radioform.png" alt="Radioform" rotation={-3} />
    </div>
  );
}
