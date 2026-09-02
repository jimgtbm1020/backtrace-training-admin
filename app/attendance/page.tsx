'use client';

import {useEffect} from 'react';

export default function AttendanceModuleHandoff(){
  useEffect(()=>{window.location.replace('https://backtrace-training-tracker.vercel.app/attendance');},[]);
  return <main className="shell"><section className="card"><h1>Training Sign-Up &amp; Attendance</h1><p>Opening the full attendance module…</p><a href="https://backtrace-training-tracker.vercel.app/attendance">Open attendance module</a></section></main>;
}
