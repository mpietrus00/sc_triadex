# Triadex Muse — Synth-DIY Mailing List Thread (June 2008)

**Source:** synth-diy mailing list, June 2008 archive  
**Thread subject:** [sdiy] TRIADEX MUSE schematics???  
**Archive URL:** https://synth-diy.org/pipermail/synth-diy/2008-June/subject.html#110143  
**Messages:** 8 (110143–110155)

---

## Message 1

**From:** Dan Snazelle <subjectivity@hotmail.com>  
**Date:** Sat Jun 21 19:55:11 CEST 2008  
**URL:** https://synth-diy.org/pipermail/synth-diy/2008-June/110143.html

Does anyone happen to know where to find the MUSE schematics? I am looking for some more pseudo random sound generators to explore. Similar ideas are welcome as well.

thanks

---

## Message 2

**From:** John Loffink <jloffink@austin.rr.com>  
**Date:** Sat Jun 21 20:49:42 CEST 2008  
**URL:** https://synth-diy.org/pipermail/synth-diy/2008-June/110144.html

I've never seen a complete Muse schematic. Most of the digital chips are obsolete anyway.

There is a simplified block diagram of the Muse in Hal Chamberlin's *Musical Applications of Microprocessors*, Chapter 10.

---

## Message 3

**From:** Ken Stone <sasami@hotkey.net.au>  
**Date:** Sun Jun 22 05:17:25 CEST 2008  
**URL:** https://synth-diy.org/pipermail/synth-diy/2008-June/110145.html

There was something in *Electronics and Music Maker* back in the 80's, with a software emulation. There is an emulator somewhere on the web that I've played with. The patent covers the basics of the original.

- **Patent number:** 3610801

---

## Message 4

**From:** Dan Snazelle <subjectivity@hotmail.com>  
**Date:** Sun Jun 22 07:36:41 CEST 2008  
**URL:** https://synth-diy.org/pipermail/synth-diy/2008-June/110146.html

I have been looking at the patent but don't get what a parity generator is, or how the major scale translation logic works. I am more interested in figuring out how to use the concepts than actually building one.

---

## Message 5

**From:** Ben Lincoln <blincoln@eventualdecline.com>  
**Date:** Sun Jun 22 08:21:13 CEST 2008  
**URL:** https://synth-diy.org/pipermail/synth-diy/2008-June/110148.html

Dan, if you haven't found it already, the software simulation documentation includes an explanation of how the parity is calculated and how the scale translation works:

- **Muse Specification / Software Simulation Docs:** http://www.trovar.com/muse/musespec.html

---

## Message 6

**From:** Tim Ressel <madhun2001@yahoo.com>  
**Date:** Sun Jun 22 11:29:41 CEST 2008  
**URL:** https://synth-diy.org/pipermail/synth-diy/2008-June/110151.html

I built one from the diagram in the Chamberlin book. It's fun, but really needs to be expanded.

An example of the parity generator, or parity tree, can be seen here:
- **74180 parity chip datasheet:** http://ceee.ytu.edu.cn/uploads/74pdf/74180.pdf

The output logic is courtesy of Ken Stone. His Diatonic Convertor is a great example of how to do the output. It is what [I] used.

---

## Message 7

**From:** mcb, inc. (Monty Brandenberg) <mcbinc@panix.com>  
**Date:** Sun Jun 22 19:04:51 CEST 2008  
**URL:** https://synth-diy.org/pipermail/synth-diy/2008-June/110154.html

Someone else tracked me down so I wrote up the following on the Muse's controls (actual Muse, not simulated):

### Switch Rows (Data Sources)

**Off / On**  
These are just fixed boolean values.

**C1/2, C1, C2, C4, C8, C3, C6**  
These are various divisions of the clock.
- **C1/2** — fastest, toggling twice per step. Is 'on' in the hold state.
- **C1** — raw tempo.
- **C2** — half-speed.
- **C3** — divide-by-three.
- A major use of these is to incorporate them into the interval logic, which can give the resulting sequence a recognizable rhythm or even a distinct time signature.

**B1–B31**  
The shift register. The pseudo-random logic generates a single bit which is fed into B1, shifting the other values down every C1 tick.

### Switch Columns (Data Consumers)

**Interval A, B, C and D**  
These determine the note pitches. A '1' in each column raises by:
- **A** — a second
- **B** — a third
- **C** — a fifth
- **D** — an octave

This is above the coarse/fine setting which establishes the 0000 base. An obvious mod would be to support many cultural tunings.

**Theme W, X, Y and Z**  
The inputs to the pseudo-random generator. Suspected logic:
```
!((W xor X) xor (Y xor Z))
```
(Not proven at time of writing. Other generators might be interesting — or not.)

### Other Controls

**Rest**  
When up, 0000 notes don't sound and become rests instead. Can sound better.

**External**  
Involves the accessory sockets.

**Start**  
Momentary position that zeros the clock (C*) and shift register (B*) values.

**Step**  
Another momentary to single step when in hold mode. Auto mode just free runs.

> Except for the external mode, verification of the pseudo-random logic and the precise behavior of the internal steps across the tuning range, that's pretty much the device in total.

---

## Message 8

**From:** Dan Snazelle <subjectivity@hotmail.com>  
**Date:** Sun Jun 22 19:23:34 CEST 2008  
**URL:** https://synth-diy.org/pipermail/synth-diy/2008-June/110155.html

Thanks a lot.

---

## Summary of Key References

| Resource | URL / Info |
|---|---|
| Patent | US Patent #3610801 |
| Software simulation / spec | http://www.trovar.com/muse/musespec.html |
| Block diagram | Hal Chamberlin, *Musical Applications of Microprocessors*, Chapter 10 |
| Parity generator example | 74180 chip datasheet — http://ceee.ytu.edu.cn/uploads/74pdf/74180.pdf |
| Diatonic Convertor (output logic) | Ken Stone — http://www.cgs.synth.net/ |
| Original magazine article | *Electronics and Music Maker* (1980s), with software emulation |

---

## Key Technical Points

- No complete schematic is publicly known (as of June 2008); original chips are largely obsolete.
- The Muse uses a **31-bit shift register (B1–B31)** clocked at tempo rate (C1).
- A **parity/XNOR tree** fed by Theme switches (W, X, Y, Z) generates a pseudo-random bit stream: `!((W xor X) xor (Y xor Z))`
- **Interval logic** (A/B/C/D columns) maps 4-bit shift register values to musical intervals (2nd, 3rd, 5th, octave) above a base pitch set by coarse/fine controls.
- **Clock dividers** (C1/2, C1, C2, C3, C4, C6, C8) can be routed to interval columns to impart rhythmic patterns.
- The Rest switch silences 0000 note values (turns them into rests).
- The Start switch resets both clock and shift register.
- Step mode allows single-stepping through sequences while in Hold mode.
