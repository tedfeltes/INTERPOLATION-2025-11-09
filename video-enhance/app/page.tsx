import { EnhanceStudio } from "@/components/enhance-studio";

export default function Home() {
  return (
    <main className="relative z-10 mx-auto flex min-h-screen w-full max-w-6xl flex-col gap-8 px-6 py-10">
      <header className="flex flex-col gap-2">
        <div className="flex items-center gap-3">
          <span className="inline-flex h-9 w-9 items-center justify-center rounded-lg bg-accent/10 text-accent">
            <svg
              width="18"
              height="18"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.8"
              strokeLinecap="round"
              strokeLinejoin="round"
              aria-hidden
            >
              <path d="M4 6h12v12H4z" />
              <path d="m16 10 4-2v8l-4-2z" />
            </svg>
          </span>
          <div>
            <h1 className="text-xl font-semibold tracking-tight">
              Video Enhance
              <span className="ml-2 rounded-md border border-border bg-elev px-1.5 py-0.5 align-middle text-[10px] font-normal uppercase tracking-widest text-muted">
                Local
              </span>
            </h1>
            <p className="text-sm text-muted">
              Enhance and clean up a video on your own machine. Nothing is
              uploaded anywhere — files never leave <code>localhost</code>.
            </p>
          </div>
        </div>
      </header>

      <EnhanceStudio />

      <footer className="mt-auto pt-8 text-xs text-muted">
        Runs entirely on your machine via <code>ffmpeg</code>. Source video and
        outputs live under <code>./.jobs/</code> in this project directory.
      </footer>
    </main>
  );
}
