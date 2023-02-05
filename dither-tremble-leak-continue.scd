Server.local.options.numOutputBusChannels = 6;
(//https://github.com/jeremy-keenan/dither-tremble-leak-continue
s.waitForBoot{
	Buffer.loadDialog(action: {arg buffer; ~b1 = buffer.read(buffer.path)});
	Buffer.loadDialog(action: {arg buffer; ~b2 = buffer.read(buffer.path)});
	//a point of reentry already before the beginning
	~b3 = Buffer.alloc(s, 44100 * 8.0, 1);
	s.sync;
	//ear as mouth
	SynthDef(\amplitude, {arg inBus = 0, rate = 60;
		var amp = Amplitude.kr(SoundIn.ar(inBus) + In.ar(inBus));
		SendReply.kr(Impulse.kr(rate), '/analysis', [amp]);
	}).play(~mix, [\inBus, 0], \addToTail);
	//world as dither
	OSCdef(\listener).free;
	~netAddr = NetAddr("127.0.0.1", 5000);
	OSCdef(\listener, {arg msg; var data = msg[3..];
		~amp = data[0];
	}, '/analysis');
	//continue
	~gen = Group.new;
	~proc = Group.new(~gen, \addAfter);
	~mix = Group.new(~proc, \addAfter);
	~rec = Group.new(~mix, \addAfter);
	~scale = Scale.minor(\just);
	~gens = Array.with(\additive, \crossed, \banded, \grains);
	~dsp = Array.with(\reson, \flange, \pitcher, \phaser, \spitcher, \brickwall, \svf, \infverb, \scramble, \comb, \rectcomb, \psp, \trem, \conmap, \svf, \delay, \chorus);
	//forms of trembling
	SynthDef("trem", {arg inBus = 0, outBus = 0, gate = 1, atk = 0.1, dc = 0.1, sus = 1, rel = 0.1, curve = 1, outAmp = 0.5, wet = 1, modFreq = 0, depth = 1;
		var sig, env;
		sig = In.ar(inBus, 1) * (SinOsc(modFreq).range(0,1) * depth);
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet, curve), doneAction: 2);
		XOut.ar(outBus, env, sig);
	}).add;

	SynthDef("conmap", {arg inBus = 0, outBus = 0, gate = 1, atk = 0.1, sus = 1, rel = 0.1, curve = 1, image = 0,  real = 0, outAmp = 1, wet = 1;
		var sig, env, chain;
		chain = FFT(LocalBuf(8192, 1), In.ar(inBus, 1));
		chain = PV_ConformalMap(chain, real, image);
		sig = IFFT(chain) * outAmp;
		sig = Limiter.ar(sig);
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet * 0.75, curve), doneAction: 2);
		XOut.ar(outBus, env, sig);
	}).add;

	SynthDef("delay", {arg inBus = 0, outBus = 0, atk = 0.1, sus = 1, rel = 0.1, curve = 1, gate = 1, outAmp = 0.25, wet = 1, delTime = 0.1, fbk = 0.5;
		var sig, env;
		sig = SwitchDelay.ar(In.ar(inBus, 1), 1, 1, delTime, fbk, 4);
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet, curve), doneAction: 2);
		XOut.ar(outBus, env, sig);
	}).add;

	SynthDef("rectcomb", {arg inBus = 0, outBus = 0, gate = 1 , atk = 0.1, dec = 0.1, sus = 1, rel = 0.1, curve = 1, phase = 0, teeth = 0, outAmp = 1, wet = 1, width = 0.5;
		var sig, env, chain;
		chain = FFT(LocalBuf(8192), In.ar(inBus, 1));
		chain = PV_RectComb(chain, teeth, phase, width);
		sig = IFFT(chain) * outAmp;
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet, curve), doneAction: 2);
		XOut.ar(outBus, env, sig);
	}).add;

	SynthDef("comb", {arg inBus = 0, outBus = 0, freq = 1000, res = 0.1, gate = 1, atk = 0.1, dec = 0.1, sus = 1, rel = 0.1, curve = 1, outAmp = 1, wet = 1;
		var sig, sig2, mixed, env;
		sig = In.ar(inBus, 1);
		sig2 = CombC.ar(sig, 0.10, freq.reciprocal, res);
		mixed = sig + sig2 * outAmp;
		mixed= LeakDC.ar(mixed);
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet , curve), doneAction: 2);
		XOut.ar(outBus, env, mixed * 0.35);
	}).add;

	SynthDef("scramble", {arg inBus = 0, outBus = 0, gate = 1 , atk = 0.1, dec = 0.1, sus = 1,rel = 0.1, curve = 1, wipe = 1, width = 0.5, outAmp = 1, wet = 1;
		var sig, env, chain;
		chain = FFT(LocalBuf(8192), In.ar(inBus, 1));
		chain = PV_BinScramble(chain, wipe, width, 1);
		sig = IFFT(chain) * outAmp;
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet, curve), doneAction: 2);
		XOut.ar(outBus, env, sig);
	}).add;

	SynthDef("infverb", {arg inBus = 0, outBus = 0,  gate = 1, atk = 0.1, dec = 0.1, sus = 1, rel = 0.1, curve = 1, decay = 0.7, outAmp = 1,  wet = 1;
		var sig, env, local;
		sig = In.ar(inBus, 1);
		local = LocalIn.ar(1) + sig;
		25.do{local =  AllpassC.ar(local, 0.06, Rand(0.001, 0.06), 3)};
		local = Select.ar(CheckBadValues.ar(local, 0, 0), [local, DC.ar(0), DC.ar(0), local]);
		local = Limiter.ar(sig);
		LocalOut.ar(local * decay);
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet, curve), doneAction: 2);
		XOut.ar(outBus, env, local * outAmp);
	}).add;

	SynthDef("svf", {arg inBus = 0, outBus = 0, freq = 1000, res = 0.5, gate = 1, atk = 0.1, dec = 0.1, sus = 1, rel = 0.1, curve = 1, low = 0, band = 1, high = 0,notch = 0, peak = 0, outAmp = 1, wet = 1;
		var sig, env;
		sig = SVF.ar(In.ar(inBus, 1), freq.abs, res, low, band, high, notch, peak);
		sig = sig * outAmp;
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet, curve), doneAction: 2);
		XOut.ar(outBus, env, sig);
	}).add;
	s.sync;
	SynthDef("brickwall", {arg inBus = 0, outBus = 0, freq = 0,  gate = 1, filtype = 1 , atk = 0.1,   dec = 0.1, sus = 1, rel = 0.1, curve = 1,outAmp = 1, wet = 1;
		var sig, env, chain;
		freq = 2 * freq/s.sampleRate * filtype;
		chain = FFT(LocalBuf(8192), In.ar(inBus, 1));
		chain = PV_BrickWall(chain, freq);
		sig = IFFT(chain) * outAmp;
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet, curve), doneAction: 2);
		XOut.ar(outBus, env, sig);
	}).add;

	SynthDef("spitcher", {arg inBus = 0, outBus = 0, freq = 1, gate = 1, pitchDisp = 0.01, timeDisp = 0.01 , atk = 0.1, dec = 0.1, rel = 0.11, decay = 0.8, curve = 1, delTime = 0.1,  sus = 1, outAmp = 1, wet = 1;
		var sig, env, local, del;
		sig = In.ar(inBus, 1);
		local = LocalIn.ar(1) + sig;
		local = PitchShift.ar(local, 0.3, (freq.cpsmidi - 60).midiratio, pitchDisp, timeDisp);
		local = DelayC.ar(local, 4, delTime);
		local = Select.ar(CheckBadValues.ar(local, 0, 0), [local, DC.ar(0), DC.ar(0), local]);
		sig = Limiter.ar(sig);
		LocalOut.ar(local * decay);
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet, curve), doneAction: 2);
		XOut.ar(outBus, env, local * outAmp);
	}).add;

	SynthDef("pitcher", {arg inBus = 0, outBus = 0, freq = 1000, gate = 1,  pitchDisp = 0.001, timeDisp = 0.001 , atk = 0.1, dec = 0.1, rel = 0.11, curve = 1, sus = 1,  outAmp = 1, wet = 1;
		var sig, env;
		sig = PitchShift.ar(In.ar(inBus, 1), 0.3, (freq.cpsmidi - 60).midiratio , pitchDisp , timeDisp);
		sig = sig * outAmp;
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet, curve), doneAction: 2);
		XOut.ar(outBus, env, sig);
	}).add;

	SynthDef("reson", {arg inBus = 0, outBus = 0, freq = 500, bwr = 3, gate = 1 , atk = 0.1, dec = 0.1, rel = 0.1, curve = 1, sus = 1,  outAmp = 1, wet = 1;
		var sig, env;
		sig = Resonz.ar(In.ar(inBus, 1), freq, bwr);
		sig = sig * outAmp;
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet, curve), doneAction: 2);
		XOut.ar(outBus, env, sig);
	}).add;

	SynthDef("phaser", {arg inBus = 0, outBus = 0, freq = 1000, res = 0, gate = 1, atk = 0.1, dec = 0.1, sus = 1, rel = 0.1, curve = 1, outAmp = 1, wet = 1;
		var sig, sig2, env, mixed;
		sig = In.ar(inBus, 1);
		sig2 = AllpassC.ar(AllpassC.ar(AllpassC.ar(AllpassC.ar(AllpassC.ar(AllpassC.ar(AllpassC.ar(AllpassC.ar(sig, 0.10, freq.reciprocal, res), 0.10,  freq.reciprocal, res ), 0.10,  freq.reciprocal, res), 0.10,  freq.reciprocal, res), 0.10,  freq.reciprocal, res, 0.10),  freq.reciprocal, res), 0.10,  freq.reciprocal, res), 0.10,  freq.reciprocal, res);
		mixed = sig + sig2 * outAmp;
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet , curve), doneAction: 2);
		XOut.ar(outBus, env, mixed);
	}).add;

	SynthDef("chorus", {arg inBus = 0, outBus = 0, modRate = 0.001, maxDelay = 0.05, minDelay = 0.01, gate = 1, atk = 0.1, dec = 0.1,sus = 1, rel = 0.1, curve = 1,dry = 0, wet = 1, amp = 1;
		var sig, env, lfos, chorus;
		sig = In.ar(inBus, 1) * 8.reciprocal;
		lfos = Array.fill(8, {SinOsc.ar(modRate * rrand(0.95, 1.05), rrand(0.0, 1.0), (maxDelay * 0.5) - minDelay,  (maxDelay * 0.5) + minDelay)});
		chorus = DelayC.ar(sig, maxDelay, lfos);
		chorus = Mix.ar(chorus);
		sig = (dry * sig) + (wet * chorus);
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet, curve), doneAction: 2);
		XOut.ar(outBus, env, sig);
	}).add;

	SynthDef("flange", {arg inBus = 0, outBus = 0, modRate = 1,gate = 1, atk = 0.1, dec = 0.1, sus = 1, rel = 0.1, maxDelay = 0.01, minDelay = 0.001, decayTime = 1, curve = 1, outAmp = 1, wet = 1;
		var env, sig;
		sig = CombC.ar(In.ar(inBus, 1), maxDelay, SinOsc.ar(modRate, 0, (maxDelay * 0.5) - minDelay, (maxDelay * 0.5) + minDelay), decayTime, outAmp);
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet , curve), doneAction: 2);
		XOut.ar(outBus, env, sig);
	}).add;

	SynthDef("psp", {arg inBus = 0, outBus = 0, threshold = 10, outAmp = 1, gate = 1, numFrames = 6, initFlag = 0, atk = 0.1, sus = 1, rel = 0.1, wet = 1, curve = 1;
		var sig, env, inSig, chain;
		chain = FFT({ LocalBuf(8192) } ! 1, In.ar(inBus, 1));
		chain = PV_PartialSynthP(chain, threshold, numFrames, initFlag);
		sig = IFFT(chain) * outAmp;
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet, curve), doneAction: 2);
		XOut.ar(outBus, env, sig);
	}).add;

	//leak | leap
	SynthDef("additive", {arg outBus = 0, filter = 0.5, rate = 1, atk = 0.1, sus = 1, gate = 1,filtFreq = 1000, rel = 0.1, curve = 0, verbMix = 0.5, freq = 100, numHarm = 25, mode = 0, lag = 1, freeze = 0, buf, outAmp = 1;
		var sig, sig2, verb, chain, chain1, chain2, env;
		sig = Blip.ar(freq, numHarm);
		sig2 = PlayBuf.ar(1, buf, BufRateScale.kr(buf) * rate, loop: 1);
		chain1 = FFT({ LocalBuf(8192) } ! 1, sig);
		chain2 = FFT({ LocalBuf(8192) } ! 1, sig2);
		chain = PV_SpectralMap(chain1, chain2, filter, freeze, 1, mode);
		sig = IFFT(chain) * outAmp * 0.75;
		12.do{verb =  AllpassC.ar(sig, 0.06, Rand(0.001, 0.06), 3)};
		sig = (1 - verbMix) * verb + (sig * verbMix);
		sig = BPF.ar(sig, filtFreq, 0.1);
		env = EnvGen.kr(Env.linen(atk,sus,rel ,1, curve), doneAction: 2);
		Out.ar(outBus, sig * env);
	}).add;
	s.sync;
	SynthDef("banded", {arg inBus = 0, outBus = 0, freq = 100, rate = 2, numHarm = 25, verbMix = 0.5, atk = 0.1, sus = 1, rel = 0.1, curve = 0, mode = 0, buf, amp = 2;
		var voiced, sig, numBands, bandFreqs, carrier, verb, env;
		bandFreqs = (0..32 - 1).linexp(0, 32 - 1, 100, 8000);
		sig = PlayBuf.ar(1, buf, BufRateScale.kr(buf) * rate, loop: 1);
		voiced = Blip.ar(freq, numHarm);
		carrier = SelectX.ar((ZeroCrossing.ar(sig).cpsmidi.lag(0.1) > 5000.cpsmidi).lag(0.05), [voiced, PinkNoise.ar]);
		sig = Amplitude.ar(BPF.ar(sig, bandFreqs, 0.05), 0.01, 0.05);
		sig = (BPF.ar(carrier, bandFreqs, 0.001) * sig).sum  * 30.dbamp;
		12.do{verb =  AllpassC.ar(sig, 0.06, Rand(0.001, 0.06), 3)};
		sig = (1 - verbMix) * verb + (sig * verbMix);
		env = EnvGen.kr(Env.linen(atk,sus,rel,1, curve), doneAction: 2);
		Out.ar(outBus, sig * env);
	}).add;
	s.sync;
	SynthDef("crossed", {arg inBus = 0, outBus = 0, rate1 = 2, rate2 = 2, numHarm = 25, verbMix = 0.5, atk = 0.1, sus = 1, rel = 0.1, curve = 0, buf1, buf2, amp = 2;
		var voiced, sig, bandFreqs, carrier, verb, env;
		bandFreqs = (0..32 - 1).linexp(0, 32 - 1, 100, 8000);
		sig = PlayBuf.ar(1, buf1, BufRateScale.kr(buf1) * rate1, loop: 1);
		voiced = PlayBuf.ar(1, buf2, BufRateScale.kr(buf2) * rate2, loop: 1);
		carrier = SelectX.ar((ZeroCrossing.ar(sig).cpsmidi.lag(0.1) > 5000.cpsmidi).lag(0.05), [voiced, PinkNoise.ar]);
		sig = Amplitude.ar(BPF.ar(sig, bandFreqs, 0.05), 0.01, 0.05);
		sig = (BPF.ar(carrier, bandFreqs, 0.001) * sig).sum  * 30.dbamp;
		12.do{verb =  AllpassC.ar(sig, 0.06, Rand(0.001, 0.06), 3)};
		sig = (1 - verbMix) * verb + (sig * verbMix);
		env = EnvGen.kr(Env.linen(atk,sus,rel,1, curve), doneAction: 2);
		Out.ar(outBus, sig * env);
	}).add;
	s.sync;
	SynthDef("grains", {arg in = 0, outBus = 0,freq = 1, filtFreq = 10000, atk = 0.1, sus = 1, trig = 10, dur = 0.1, traverse = 0.01, rel = 0.1, curve = 0, buf3, outAmp = 1;
		var sig, env;
		sig = BufGrain.ar(Impulse.ar(trig), dur, buf3, BufRateScale.kr(buf3) * (freq.cpsmidi - 60).midiratio, LFSaw.ar(traverse),4);
		sig = BPF.ar(sig, filtFreq, 0.1);
		sig = sig * outAmp ;
		env = EnvGen.kr(Env.linen(atk,sus,rel,1, curve), doneAction: 2);
		Out.ar(outBus, sig * env);
	}).add;
	s.sync;

	//single body
	SynthDef("mix", {arg inBus = 0, outBus = 0, limit = 0.9;
		var sig, sig2;
		sig = Splay.ar(In.ar(inBus, 4), 1, 1, -1);
		sig2 = Splay.ar(In.ar(inBus, 4), 1, 1, 1);
		sig = (sig + sig2);
		sig = BLowShelf.ar(sig, 250.0, 1.0, 10.0);
		sig = BPeakEQ.ar(sig,4000.0, 2, - 8.0);
		sig = BHiShelf.ar(sig, 10000.0, 1.0,  6.0);
		sig = Limiter.ar(sig, limit);
		ReplaceOut.ar(outBus, sig);
	}).play(~mix, [\inBus, 2, \outBus, 0], \addToHead);
	s.sync;

	//Klein bottle
	SynthDef("record", { arg out = 0, buf = 0, inBus = 0;
		RecordBuf.ar(In.ar(inBus), buf, 0, 1, 0, 1 , 1, 1);
	}).play(~rec, [\inBus, 0, \outBus, 0, \buf, ~b3], \addToHead);
	s.sync;

	//distribute
	Pdef(\GEN, Pbind(
		\instrument, Pxrand(~gens, inf).trace,
		\group, ~gen,
		\addAction, \addToTail,
		\outBus, Pfunc({((~amp * 10000) % 1.0).range(2,5).round}),
		\buf, ~b1,
		\buf1, ~b1,
		\buf2, ~b2,
		\buf3, ~b3,
		\freq, Pfunc({~scale.degreeToFreq(((~amp * 10000) % 1.0).range(0,7), 36, ((~amp * 10000) % 1.0).range(1,5))}),
		\rate, Pfunc({((~amp * 10000) % 1.0).range(-1,1)}),
		\rate1, Pfunc({((~amp * 10000) % 1.0).range(-2,2)}),
		\rate2, Pfunc({((~amp * 10000) % 1.0).range(-2,2)}),
		\trig, Pfunc({((~amp * 10000) % 1.0).range(0.1,10)}),
		\dur, Pfunc({((~amp * 10000) % 1.0).range(0.01,0.2)}),
		\traverse, Pfunc({((~amp * 10000) % 1.0).range(0.01,2)}),
		\filter, Pfunc({((~amp * 10000) % 1.0).range(0.001,0.2)}),
		\numHarm, Pfunc({((~amp * 10000) % 1.0).range(5,20).round}),
		\verbMix, Pfunc({((~amp * 10000) % 1.0).range(0.1,0.5)}),
		\timeFac, Pseq([Pfunc({((~amp * 10000) % 1.0).range(0.5,2)})], inf),
		\atk, Pfunc({((~amp * 10000) % 1.0).range(5,10)}) * Pkey(\timeFac),
		\sus, Pfunc({((~amp * 10000) % 1.0).range(20,40)}) * Pkey(\timeFac),
		\rel, Pfunc({((~amp * 10000) % 1.0).range(5,25)}) * Pkey(\timeFac),
		\curve, Pfunc({((~amp * 10000) % 1.0).range(-1,1)}),
		\dur, 15 * Pkey(\timeFac),
	)
	).play;
	s.sync;

	//murumurate
	Pdef(\DSP, Pbind(
		\instrument, Pxrand(~dsp, inf).trace,
		\group, ~proc,
		\addAction, \addToTail,
		\inBus, Pfunc({((~amp * 10000) % 1.0).range(2,5).round}),
		\outBus, Pkey(\inBus),
		\modFreq, Pfunc({((~amp * 10000) % 1.0).range(0.1,3)}),
		\modRate, Pfunc({((~amp * 10000) % 1.0).range(0.0001,0.05)}),
		\depth, Pfunc({((~amp * 10000) % 1.0).range(0.1,0.9)}),
		\freq, Pfunc({~scale.degreeToFreq(((~amp * 10000) % 1.0).range(0,7), 36, ((~amp * 10000) % 1.0).range(1,4))}),
		\res, Pfunc({((~amp * 10000) % 1.0).range(0.1,0.8)}),
		\filtFreq, Pfunc({~scale.degreeToFreq(((~amp * 10000) % 1.0).range(0,7), 36, ((~amp * 10000) % 1.0).range(3,8))}),
		\filType, Pfunc({((~amp * 10000) % 1.0).range(0,2).round}),
		\decayTime, Pfunc({((~amp * 10000) % 1.0).range(0.001,0.1)}),
		\decay, Pfunc({((~amp * 10000) % 1.0).range(0.2,0.85)}),
		\delTime, Pfunc({((~amp * 10000) % 1.0).range(0.1,2)}),
		\fbk, Pfunc({((~amp * 10000) % 1.0).range(0.1,0.8)}),
		\curve, Pfunc({((~amp * 10000) % 1.0).range(-1,1)}),
		\shift, Pfunc({((~amp * 10000) % 1.0).range(-128,128)}),
		\numFrames, Pfunc({((~amp * 10000) % 1.0).range(10,128)}),
		\phase, Pfunc({((~amp * 10000) % 1.0).range(-1,1)}),
		\teeth, Pfunc({((~amp * 10000) % 1.0).range(1,24)}),
		\width, Pfunc({((~amp * 10000) % 1.0).range(0.1,0.9)}),
		\wipe, Pfunc({((~amp * 10000) % 1.0).range(0.1,0.9)}),
		\bwr, Pfunc({((~amp * 10000) % 1.0).range(0.1,5)}),
		\image , Pfunc({((~amp * 10000) % 1.0).range(-1,1)}),
		\real, Pfunc({((~amp * 10000) % 1.0).range(-1,1)}),
		\freeze, Pfunc{[0, 1].choose},
		\pitchDisp, Pfunc({((~amp * 10000) % 1.0).range(0.001,0.01)}),
		\timeDisp, Pfunc({((~amp * 10000) % 1.0).range(0.001,0.01)}),
		\threshold, Pfunc({((~amp * 10000) % 1.0).range(0.1,6)}),
		\low, Pfunc({((~amp * 10000) % 1.0).range(0.1,0.4)}),
		\band, Pfunc({((~amp * 10000) % 1.0).range(0.1,0.4)}),
		\high, Pfunc({((~amp * 10000) % 1.0).range(0.1,0.4)}),
		\notch, Pfunc({((~amp * 10000) % 1.0).range(0.1,0.4)}),
		\peak, Pfunc({((~amp * 10000) % 1.0).range(0.1,0.4)}),
		\timeFac, Pfunc({((~amp * 10000) % 1.0).range(0.5,2)}),
		\atk, Pfunc({((~amp * 10000) % 1.0).range(5,10)}) * Pkey(\timeFac),
		\sus, Pfunc({((~amp * 10000) % 1.0).range(20,30)}) * Pkey(\timeFac),
		\rel, Pfunc({((~amp * 10000) % 1.0).range(5,10)}) * Pkey(\timeFac),
		\dur, 20 * Pkey(\timeFac),
	)
	).play;
	//emerge
};
)

