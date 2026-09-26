import React from 'react';

export interface TelemetryData {
  time: string;
  seconds: string;
  ampm: string;
  date: string;
  batteryDays: number;
  gpsStatus: 'FIX' | 'SEARCHING' | 'OFF';
  altitude: number;
  barometer: number;
  heartRate: number;
  hrZone: number; // 1 to 5
  vo2Max: number;
  solarPct: number;
  steps: number;
  rampRate: number;
  recoveryHours: number;
}

export const MarkEnduroWatchFace: React.FC<{ data: TelemetryData }> = ({ data }) => {
  return (
    <div className="relative flex h-[280px] w-[280px] flex-col items-center justify-between overflow-hidden rounded-full bg-black p-3 font-mono text-[11px] text-white select-none">
      {/* Outer Solar Arc Indicator */}
      <div 
        className="absolute inset-0 rounded-full border-2 border-cyan-400/30"
        style={{ clipPath: `polygon(50% 50%, 0 0, ${data.solarPct}% 0)` }}
      />

      {/* Top Header Section */}
      <header className="z-10 mt-1 flex w-full justify-between px-6 text-[10px]">
        <span className="text-cyan-400 font-bold">/// ARC-HUD v3.0 \\\</span>
      </header>

      {/* Status Bar */}
      <div className="z-10 flex w-full justify-between px-5 text-[10px]">
        <div className="flex items-center gap-1">
          <span className="text-zinc-400">BAT:</span>
          <span className="font-bold">{data.batteryDays}D</span>
        </div>
        <div className="flex items-center gap-1">
          <span className="text-zinc-400">GPS:</span>
          <span className={data.gpsStatus === 'FIX' ? 'text-cyan-400 font-bold' : 'text-amber-500'}>
            {data.gpsStatus}
          </span>
        </div>
      </div>

      {/* Atmospheric Mid Section */}
      <div className="z-10 flex w-full justify-between px-3 text-[10px] text-zinc-300">
        <span>( ALT: {data.altitude.toLocaleString()}m )</span>
        <span>( BARO: {data.barometer} hPa )</span>
      </div>

      {/* Primary Time Core */}
      <main className="z-10 my-0.5 flex flex-col items-center border-y border-zinc-800 py-1 w-full bg-zinc-950/80">
        <div className="flex items-baseline gap-1">
          <span className="text-3xl font-black tracking-tight text-white">{data.time}</span>
          <span className="text-sm font-bold text-cyan-400">{data.seconds}</span>
          <span className="text-[9px] text-zinc-400">{data.ampm}</span>
        </div>
        <div className="text-[9px] tracking-widest text-zinc-400 uppercase">
          {data.date}
        </div>
      </main>

      {/* Fitness & Environmental Metrics */}
      <div className="z-10 grid w-full grid-cols-2 gap-x-2 px-3 text-[10px]">
        <div className="flex items-center justify-between">
          <span className="text-zinc-400">HR:</span>
          <span className="font-bold text-white">{data.heartRate} <span className="text-[8px] text-zinc-500">bpm</span></span>
        </div>
        <div className="flex items-center justify-between">
          <span className="text-zinc-400">VO2 Max:</span>
          <span className="font-bold text-cyan-400">{data.vo2Max}</span>
        </div>
        <div className="flex items-center justify-between">
          <span className="text-zinc-400">STP:</span>
          <span className="font-bold text-white">{data.steps.toLocaleString()}</span>
        </div>
        <div className="flex items-center justify-between">
          <span className="text-zinc-400">SOLR:</span>
          <span className="font-bold text-cyan-400">{data.solarPct}%</span>
        </div>
      </div>

      {/* Bottom Footer Section */}
      <footer className="z-10 mb-1 flex flex-col items-center gap-0.5 text-[9px]">
        <div className="text-cyan-400">--- RAMP RATE: +{data.rampRate}% ---</div>
        <div className="text-zinc-400">[RECOVERY: {data.recoveryHours}h]</div>
      </footer>
    </div>
  );
};