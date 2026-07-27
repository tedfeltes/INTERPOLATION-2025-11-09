import { Badge } from "@/components/ui/badge"

export function SiteHeader() {
  return (
    <header className="flex items-center justify-between border-b border-border px-4 py-3.5 backdrop-blur-md sm:px-6">
      <div className="flex items-center gap-2.5">
        <span
          className="relative size-[1.1rem] rounded-full border-2 border-primary shadow-[inset_0_0_0_3px_var(--background),0_0_0_1px_var(--accent-soft)]"
          aria-hidden="true"
        >
          <span className="absolute top-1/2 left-1/2 h-[0.85rem] w-0.5 origin-bottom -translate-x-1/2 -translate-y-[10%] rotate-[28deg] bg-primary" />
        </span>
        <span className="font-display text-base font-extrabold tracking-wide">
          StakeDXF
        </span>
      </div>
      <Badge
        variant="outline"
        className="rounded-full border-[rgba(228,87,46,0.35)] font-mono text-[0.65rem] text-accent-soft sm:text-[0.72rem]"
      >
        iPhone · TSC5 · OneDrive
      </Badge>
    </header>
  )
}
