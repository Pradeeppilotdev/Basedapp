'use client';

import { useEffect, useState } from 'react';

interface CountdownProps {
  timeRemaining: number;
}

export function Countdown({ timeRemaining }: CountdownProps) {
  const [time, setTime] = useState(timeRemaining);

  useEffect(() => {
    setTime(timeRemaining);
  }, [timeRemaining]);

  useEffect(() => {
    if (time <= 0) return;

    const timer = setInterval(() => {
      setTime((prev) => Math.max(0, prev - 1));
    }, 1000);

    return () => clearInterval(timer);
  }, [time]);

  const hours = Math.floor(time / 3600);
  const minutes = Math.floor((time % 3600) / 60);
  const seconds = time % 60;

  return (
    <div className="bg-gradient-to-r from-purple-600 to-indigo-600 rounded-2xl shadow-2xl p-8 text-center text-white">
      <h2 className="text-2xl font-bold mb-4">Next Draw In</h2>
      <div className="flex justify-center gap-4">
        <TimeUnit value={hours} label="Hours" />
        <div className="text-4xl font-bold self-center">:</div>
        <TimeUnit value={minutes} label="Minutes" />
        <div className="text-4xl font-bold self-center">:</div>
        <TimeUnit value={seconds} label="Seconds" />
      </div>
      {time === 0 && (
        <p className="mt-4 text-sm">Drawing in progress...</p>
      )}
    </div>
  );
}

function TimeUnit({ value, label }: { value: number; label: string }) {
  return (
    <div className="flex flex-col items-center">
      <div className="bg-white/20 rounded-lg px-6 py-4 min-w-[80px]">
        <div className="text-5xl font-bold">
          {value.toString().padStart(2, '0')}
        </div>
      </div>
      <div className="text-sm mt-2 opacity-90">{label}</div>
    </div>
  );
}
