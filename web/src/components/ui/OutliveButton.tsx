interface OutliveButtonProps {
  variant?: "primary" | "secondary" | "destructive";
  loading?: boolean;
  children: React.ReactNode;
  onClick?: () => void;
  type?: "button" | "submit";
  disabled?: boolean;
  className?: string;
}

const variants = {
  primary: "bg-training text-white hover:opacity-90",
  secondary: "bg-transparent border border-training text-training hover:bg-training/10",
  destructive: "bg-recovery-red text-white hover:opacity-90",
};

export function OutliveButton({
  variant = "primary",
  loading = false,
  children,
  onClick,
  type = "button",
  disabled = false,
  className = "",
}: OutliveButtonProps) {
  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled || loading}
      className={`px-[var(--space-lg)] py-[var(--space-sm)] rounded-[var(--radius-sm)] font-medium transition-opacity disabled:opacity-50 ${variants[variant]} ${className}`}
    >
      {loading ? (
        <span className="flex items-center gap-2">
          <svg className="animate-spin h-4 w-4" viewBox="0 0 24 24">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" />
            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
          </svg>
          Loading...
        </span>
      ) : (
        children
      )}
    </button>
  );
}
