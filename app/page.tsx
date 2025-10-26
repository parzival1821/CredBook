'use client';
import LiquidEther from '@/components/LiquidEther';

export default function Home() {
  return (
    <div className="relative min-h-screen w-full overflow-hidden bg-black">
      {/* LiquidEther Background */}
      <div className="absolute inset-0">
        <LiquidEther
          colors={['#5227FF', '#FF9FFC', '#B19EEF']}
          mouseForce={20}
          cursorSize={100}
          autoDemo={true}
          resolution={0.5}
          autoSpeed={0.5}
          autoIntensity={2.2}
          takeoverDuration={0.25}
          autoResumeDelay={3000}
          autoRampDuration={0.6}
        />
      </div>

      {/* Content Overlay */}
      <div className="relative z-10 flex min-h-screen flex-col items-center justify-center px-4">
        <div className="max-w-4xl text-center">
          <h1 className="mb-6 text-6xl font-bold text-white md:text-7xl lg:text-8xl">
            CredBook
          </h1>
          <p className="mb-8 text-xl text-gray-200 md:text-2xl">
            On-chain orderbook for DeFi lending - matching borrowers with the best rates across competing liquidity pools.
          </p>
          <div className="flex flex-col gap-4 sm:flex-row sm:justify-center">
            <button className="rounded-lg bg-white/20 px-8 py-4 text-lg font-medium text-white backdrop-blur-sm transition-all hover:bg-white/30 hover:scale-105">
              Get Started
            </button>
            <button className="rounded-lg border-2 border-white/40 px-8 py-4 text-lg font-medium text-white backdrop-blur-sm transition-all hover:bg-white/10 hover:scale-105">
              Learn More
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}