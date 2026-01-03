export default function ScreenshotLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <>
      <style dangerouslySetInnerHTML={{
        __html: `
          body {
            background: transparent !important;
          }
          html {
            background: transparent !important;
          }
        `
      }} />
      <div style={{ background: "transparent" }}>
        {children}
      </div>
    </>
  );
}

