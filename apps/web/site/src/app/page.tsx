import Button from "@/components/Button";
import GradientContainer from "@/components/GradientContainer";

export default function Home() {
  return (
    <div className="h-screen overflow-hidden bg-background">
      {/* Navbar */}
      <nav className="flex h-16 items-center justify-between px-6">
        <div className="text-base font-medium text-primary">
          Radioform
        </div>
        <Button variant="filled">Download</Button>
      </nav>

      {/* Main Content */}
      <main className="h-[calc(100vh-64px)] overflow-hidden">
        <div className="mx-auto max-w-5xl px-6 pt-16">
          {/* Hero Text Section */}
          <div className="mb-12 -ml-6 space-y-6 text-left">
            <h1 className="text-4xl font-medium leading-tight text-primary mb-2">
              Music is meant to sound good
            </h1>
            <h2 className="text-4xl font-medium leading-tight text-primary">
              Use an EQ to hear that difference
            </h2>
            <div className="pt-4">
              <Button variant="filled">Download</Button>
            </div>
          </div>

          {/* Large Container - extends slightly off page but clipped */}
          <GradientContainer>
            {/* Container content goes here */}
          </GradientContainer>
        </div>
      </main>
    </div>
  );
}
