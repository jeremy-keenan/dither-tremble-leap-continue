Server.local.options.numOutputBusChannels = 6;
(//https://github.com/jeremy-keenan/dither-tremble-leak-continue
s.waitForBoot{
	Buffer.loadDialog(action: {arg buffer; ~b1 = buffer.read(buffer.path)});
	Buffer.loadDialog(action: {arg buffer; ~b2 = buffer.read(buffer.path)});
	//re-enter-before-the-beginning
	~b3 = Buffer.alloc(s, 44100 * 8.0, 1);

	//continue
	~gn = Group.new;
	~prc = Group.new(~gn, \addAfter);
	~mx = Group.new(~prc, \addAfter);
	~rc = Group.new(~mx, \addAfter);
	~scl = Scale.minor(\just);
	~gns = Array.with(\add, \crs, \bnd, \grn);
	~dsp = Array.with(\rsn, \flng, \ptchr, \phsr, \sptchr, \brck, \svf, \nfvrb, \scrmbl, \cmb, \rctcmb, \psp, \trm, \cnmp, \svf, \dl, \chrs);

	//ear-as-mouth
	SynthDef(\snd, {arg inBus = 0, rate = 60;
		var amp = Amplitude.kr(SoundIn.ar(inBus) + In.ar(inBus));
		SendReply.kr(Impulse.kr(rate), '/anl', [amp]);
	}).play(~mx, [\inBus, 0], \addToTail);

	//world-as-dither
	OSCdef(\lsn, {arg msg; var data = msg[3..];
		~lvl = data[0];
	}, '/anl');

	//forms-of-trembling
	SynthDef("trm", {arg inBus = 0, outBus = 0, gate = 1, atk = 0.1, dc = 0.1, sus = 1, rel = 0.1, curve = 1, outAmp = 0.5, wet = 1, modFreq = 0, depth = 1;
		var sig, env;
		sig = In.ar(inBus, 1) * (SinOsc(modFreq).range(0,1) * depth);
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet, curve), doneAction: 2);
		XOut.ar(outBus, env, sig);
	}).add;

	SynthDef("cnmp", {arg inBus = 0, outBus = 0, gate = 1, atk = 0.1, sus = 1, rel = 0.1, curve = 1, image = 0,  real = 0, outAmp = 1, wet = 1;
		var sig, env, chain;
		chain = FFT(LocalBuf(8192, 1), In.ar(inBus, 1));
		chain = PV_ConformalMap(chain, real, image);
		sig = IFFT(chain) * outAmp;
		sig = Limiter.ar(sig);
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet * 0.75, curve), doneAction: 2);
		XOut.ar(outBus, env, sig);
	}).add;

	SynthDef("dl", {arg inBus = 0, outBus = 0, atk = 0.1, sus = 1, rel = 0.1, curve = 1, gate = 1, outAmp = 0.25, wet = 1, delTime = 0.1, fbk = 0.5;
		var sig, env;
		sig = SwitchDelay.ar(In.ar(inBus, 1), 1, 1, delTime, fbk, 4);
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet, curve), doneAction: 2);
		XOut.ar(outBus, env, sig);
	}).add;

	SynthDef("rctcmb", {arg inBus = 0, outBus = 0, gate = 1, atk = 0.1, dec = 0.1, sus = 1, rel = 0.1, curve = 1, phase = 0, teeth = 0, outAmp = 1, wet = 1, width = 0.5;
		var sig, env, chain;
		chain = FFT(LocalBuf(8192), In.ar(inBus, 1));
		chain = PV_RectComb(chain, teeth, phase, width);
		sig = IFFT(chain) * outAmp;
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet, curve), doneAction: 2);
		XOut.ar(outBus, env, sig);
	}).add;

	SynthDef("cmb", {arg inBus = 0, outBus = 0, freq = 1000, res = 0.1, gate = 1, atk = 0.1, dec = 0.1, sus = 1, rel = 0.1, curve = 1, outAmp = 1, wet = 1;
		var sig, sig2, mixed, env;
		sig = In.ar(inBus, 1);
		sig2 = CombC.ar(sig, 0.10, freq.reciprocal, res);
		mixed = sig + sig2 * outAmp;
		mixed= LeakDC.ar(mixed);
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet , curve), doneAction: 2);
		XOut.ar(outBus, env, mixed * 0.35);
	}).add;

	SynthDef("scrmbl", {arg inBus = 0, outBus = 0, gate = 1 , atk = 0.1, dec = 0.1, sus = 1,rel = 0.1, curve = 1, wipe = 1, width = 0.5, outAmp = 1, wet = 1;
		var sig, env, chain;
		chain = FFT(LocalBuf(8192), In.ar(inBus, 1));
		chain = PV_BinScramble(chain, wipe, width, 1);
		sig = IFFT(chain) * outAmp;
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet, curve), doneAction: 2);
		XOut.ar(outBus, env, sig);
	}).add;

	SynthDef("nfvrb", {arg inBus = 0, outBus = 0,  gate = 1, atk = 0.1, dec = 0.1, sus = 1, rel = 0.1, curve = 1, decay = 0.7, outAmp = 1,  wet = 1;
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

	SynthDef("svf", {arg inBus = 0, outBus = 0, freq = 1000, res = 0.5, gate = 1, atk = 0.1, dec = 0.1, sus = 1, rel = 0.1, curve = 1, low = 0, band = 1, high = 0, notch = 0, peak = 0, outAmp = 1, wet = 1;
		var sig, env;
		sig = SVF.ar(In.ar(inBus, 1), freq.abs, res, low, band, high, notch, peak);
		sig = sig * outAmp;
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet, curve), doneAction: 2);
		XOut.ar(outBus, env, sig);
	}).add;

	SynthDef("brck", {arg inBus = 0, outBus = 0, freq = 0,  gate = 1, filtype = 1 , atk = 0.1, dec = 0.1, sus = 1, rel = 0.1, curve = 1,outAmp = 1, wet = 1;
		var sig, env, chain;
		freq = 2 * freq/s.sampleRate * filtype;
		chain = FFT(LocalBuf(8192), In.ar(inBus, 1));
		chain = PV_BrickWall(chain, freq);
		sig = IFFT(chain) * outAmp;
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet, curve), doneAction: 2);
		XOut.ar(outBus, env, sig);
	}).add;

	SynthDef("sptchr", {arg inBus = 0, outBus = 0, freq = 1, gate = 1, pitchDisp = 0.01, timeDisp = 0.01 , atk = 0.1, dec = 0.1, rel = 0.11, decay = 0.8, curve = 1, delTime = 0.1,  sus = 1, outAmp = 1, wet = 1;
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

	SynthDef("ptchr", {arg inBus = 0, outBus = 0, freq = 1000, gate = 1,  pitchDisp = 0.001, timeDisp = 0.001 , atk = 0.1, dec = 0.1, rel = 0.11, curve = 1, sus = 1,  outAmp = 1, wet = 1;
		var sig, env;
		sig = PitchShift.ar(In.ar(inBus, 1), 0.3, (freq.cpsmidi - 60).midiratio , pitchDisp , timeDisp);
		sig = sig * outAmp;
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet, curve), doneAction: 2);
		XOut.ar(outBus, env, sig);
	}).add;

	SynthDef("rsn", {arg inBus = 0, outBus = 0, freq = 500, bwr = 3, gate = 1 , atk = 0.1, dec = 0.1, rel = 0.1, curve = 1, sus = 1,  outAmp = 1, wet = 1;
		var sig, env;
		sig = Resonz.ar(In.ar(inBus, 1), freq, bwr);
		sig = sig * outAmp;
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet, curve), doneAction: 2);
		XOut.ar(outBus, env, sig);
	}).add;

	SynthDef("phsr", {arg inBus = 0, outBus = 0, freq = 1000, res = 0, gate = 1, atk = 0.1, dec = 0.1, sus = 1, rel = 0.1, curve = 1, outAmp = 1, wet = 1;
		var sig, sig2, env, mixed;
		sig = In.ar(inBus, 1);
		sig2 = AllpassC.ar(AllpassC.ar(AllpassC.ar(AllpassC.ar(AllpassC.ar(AllpassC.ar(AllpassC.ar(AllpassC.ar(sig, 0.10, freq.reciprocal, res), 0.10,  freq.reciprocal, res ), 0.10,  freq.reciprocal, res), 0.10,  freq.reciprocal, res), 0.10,  freq.reciprocal, res, 0.10),  freq.reciprocal, res), 0.10,  freq.reciprocal, res), 0.10,  freq.reciprocal, res);
		mixed = sig + sig2 * outAmp;
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet , curve), doneAction: 2);
		XOut.ar(outBus, env, mixed);
	}).add;

	SynthDef("chrs", {arg inBus = 0, outBus = 0, modRate = 0.001, maxDelay = 0.05, minDelay = 0.01, gate = 1, atk = 0.1, dec = 0.1,sus = 1, rel = 0.1, curve = 1,dry = 0, wet = 1, amp = 1;
		var sig, env, lfos, chorus;
		sig = In.ar(inBus, 1) * 8.reciprocal;
		lfos = Array.fill(8, {SinOsc.ar(modRate * rrand(0.95, 1.05), rrand(0.0, 1.0), (maxDelay * 0.5) - minDelay,  (maxDelay * 0.5) + minDelay)});
		chorus = DelayC.ar(sig, maxDelay, lfos);
		chorus = Mix.ar(chorus);
		sig = (dry * sig) + (wet * chorus);
		env = EnvGen.ar(Env.linen(atk, sus, rel, wet, curve), doneAction: 2);
		XOut.ar(outBus, env, sig);
	}).add;

	SynthDef("flng", {arg inBus = 0, outBus = 0, modRate = 1, gate = 1, atk = 0.1, dec = 0.1, sus = 1, rel = 0.1, maxDelay = 0.01, minDelay = 0.001, decayTime = 1, curve = 1, outAmp = 1, wet = 1;
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

	//leak-leap
	SynthDef("add", {arg outBus = 0, filter = 0.5, rate = 1, atk = 0.1, sus = 1, gate = 1,filtFreq = 1000, rel = 0.1, curve = 0, verbMix = 0.5, freq = 100, numHarm = 25, mode = 0, lag = 1, freeze = 0, buf, outAmp = 1;
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
		env = EnvGen.kr(Env.linen(atk, sus, rel, 1, curve), doneAction: 2);
		Out.ar(outBus, sig * env);
	}).add;

	SynthDef("bnd", {arg inBus = 0, outBus = 0, freq = 100, rate = 2, numHarm = 25, verbMix = 0.5, atk = 0.1, sus = 1, rel = 0.1, curve = 0, mode = 0, buf, amp = 2;
		var voiced, sig, numBands, bandFreqs, carrier, verb, env;
		bandFreqs = (0..32 - 1).linexp(0, 32 - 1, 100, 8000);
		sig = PlayBuf.ar(1, buf, BufRateScale.kr(buf) * rate, loop: 1);
		voiced = Blip.ar(freq, numHarm);
		carrier = SelectX.ar((ZeroCrossing.ar(sig).cpsmidi.lag(0.1) > 5000.cpsmidi).lag(0.05), [voiced, PinkNoise.ar]);
		sig = Amplitude.ar(BPF.ar(sig, bandFreqs, 0.05), 0.01, 0.05);
		sig = (BPF.ar(carrier, bandFreqs, 0.001) * sig).sum  * 30.dbamp;
		12.do{verb =  AllpassC.ar(sig, 0.06, Rand(0.001, 0.06), 3)};
		sig = (1 - verbMix) * verb + (sig * verbMix);
		env = EnvGen.kr(Env.linen(atk, sus, rel, 1, curve), doneAction: 2);
		Out.ar(outBus, sig * env);
	}).add;

	SynthDef("crs", {arg inBus = 0, outBus = 0, rate1 = 2, rate2 = 2, numHarm = 25, verbMix = 0.5, atk = 0.1, sus = 1, rel = 0.1, curve = 0, buf1, buf2, amp = 2;
		var voiced, sig, bandFreqs, carrier, verb, env;
		bandFreqs = (0..32 - 1).linexp(0, 32 - 1, 100, 8000);
		sig = PlayBuf.ar(1, buf1, BufRateScale.kr(buf1) * rate1, loop: 1);
		voiced = PlayBuf.ar(1, buf2, BufRateScale.kr(buf2) * rate2, loop: 1);
		carrier = SelectX.ar((ZeroCrossing.ar(sig).cpsmidi.lag(0.1) > 5000.cpsmidi).lag(0.05), [voiced, PinkNoise.ar]);
		sig = Amplitude.ar(BPF.ar(sig, bandFreqs, 0.05), 0.01, 0.05);
		sig = (BPF.ar(carrier, bandFreqs, 0.001) * sig).sum  * 30.dbamp;
		12.do{verb =  AllpassC.ar(sig, 0.06, Rand(0.001, 0.06), 3)};
		sig = (1 - verbMix) * verb + (sig * verbMix);
		env = EnvGen.kr(Env.linen(atk, sus, rel, 1, curve), doneAction: 2);
		Out.ar(outBus, sig * env);
	}).add;

	SynthDef("grn", {arg in = 0, outBus = 0, freq = 1, filtFreq = 10000, atk = 0.1, sus = 1, trig = 10, dur = 0.1, traverse = 0.01, rel = 0.1, curve = 0, buf3, outAmp = 1;
		var sig, env;
		sig = BufGrain.ar(Impulse.ar(trig), dur, buf3, BufRateScale.kr(buf3) * (freq.cpsmidi - 60).midiratio, LFSaw.ar(traverse), 4);
		sig = BPF.ar(sig, filtFreq, 0.1);
		sig = sig * outAmp ;
		env = EnvGen.kr(Env.linen(atk, sus, rel, 1, curve), doneAction: 2);
		Out.ar(outBus, sig * env);
	}).add;

	//single-body
	SynthDef("mx", {arg inBus = 0, outBus = 0, limit = 0.9;
		var sig, sig2;
		sig = Splay.ar(In.ar(inBus, 4), 1, 1, -1);
		sig2 = Splay.ar(In.ar(inBus, 4), 1, 1, 1);
		sig = (sig + sig2);
		sig = BLowShelf.ar(sig, 250.0, 1.0, 10.0);
		sig = BPeakEQ.ar(sig,4000.0, 2, - 8.0);
		sig = BHiShelf.ar(sig, 10000.0, 1.0,  6.0);
		sig = Limiter.ar(sig, limit);
		ReplaceOut.ar(outBus, sig);
	}).play(~mx, [\inBus, 2, \outBus, 0], \addToHead);
	s.sync;

	//small-bottle
	SynthDef("rcrd", {arg out = 0, buf = 0, inBus = 0;
		RecordBuf.ar(In.ar(inBus), buf, 0, 1, 0, 1 , 1, 1);
	}).play(~rc, [\inBus, 0, \outBus, 0, \buf, ~b3], \addToHead);

	//distribute
	Pdef(\GEN, Pbind(
		\instrument, Pxrand(~gns, inf).trace,
		\group, ~gn,
		\addAction, \addToTail,
		\outBus, Pfunc({((~lvl * 10000) % 1.0).range(2,5).round}),
		\buf, ~b1,
		\buf1, ~b1,
		\buf2, ~b2,
		\buf3, ~b3,
		\freq, Pfunc({~scl.degreeToFreq(((~lvl * 10000) % 1.0).range(0,7), 36, ((~lvl * 10000) % 1.0).range(1,5))}),
		\rate, Pfunc({((~lvl * 10000) % 1.0).range(-2,2)}),
		\rate1, Pfunc({((~lvl * 10000) % 1.0).range(-2,2)}),
		\rate2, Pfunc({((~lvl * 10000) % 1.0).range(-2,2)}),
		\trig, Pfunc({((~lvl * 10000) % 1.0).range(0.1,10)}),
		\dur, Pfunc({((~lvl * 10000) % 1.0).range(0.01,0.2)}),
		\traverse, Pfunc({((~lvl * 10000) % 1.0).range(0.01,2)}),
		\filter, Pfunc({((~lvl * 10000) % 1.0).range(0.001,0.2)}),
		\numHarm, Pfunc({((~lvl * 10000) % 1.0).range(5,20).round}),
		\verbMix, Pfunc({((~lvl * 10000) % 1.0).range(0.1,0.5)}),
		\timeFac, Pseq([Pfunc({((~lvl * 10000) % 1.0).range(0.5,2)})], inf),
		\atk, Pfunc({((~lvl * 10000) % 1.0).range(5,10)}) * Pkey(\timeFac),
		\sus, Pfunc({((~lvl * 10000) % 1.0).range(20,40)}) * Pkey(\timeFac),
		\rel, Pfunc({((~lvl * 10000) % 1.0).range(5,25)}) * Pkey(\timeFac),
		\curve, Pfunc({((~lvl * 10000) % 1.0).range(-1,1)}),
		\dur, 15 * Pkey(\timeFac),
	)
	).play;

	//murmurate
	Pdef(\DSP, Pbind(
		\instrument, Pxrand(~dsp, inf).trace,
		\group, ~prc,
		\addAction, \addToTail,
		\inBus, Pfunc({((~lvl * 10000) % 1.0).range(2,5).round}),
		\outBus, Pfunc({((~lvl * 15000) % 1.0).range(2,5).round}),
		\modFreq, Pfunc({((~lvl * 10000) % 1.0).range(0.1,3)}),
		\modRate, Pfunc({((~lvl * 10000) % 1.0).range(0.0001,0.05)}),
		\depth, Pfunc({((~lvl * 10000) % 1.0).range(0.1,0.9)}),
		\freq, Pfunc({~scl.degreeToFreq(((~lvl * 10000) % 1.0).range(0,7), 36, ((~lvl * 10000) % 1.0).range(1,4))}),
		\res, Pfunc({((~lvl * 10000) % 1.0).range(0.1,0.8)}),
		\filtFreq, Pfunc({~scale.degreeToFreq(((~lvl * 10000) % 1.0).range(0,7), 36, ((~lvl * 10000) % 1.0).range(3,8))}),
		\filType, Pfunc({((~lvl * 10000) % 1.0).range(0,2).round}),
		\decayTime, Pfunc({((~lvl * 10000) % 1.0).range(0.001,0.1)}),
		\decay, Pfunc({((~lvl * 10000) % 1.0).range(0.2,0.85)}),
		\delTime, Pfunc({((~lvl * 10000) % 1.0).range(0.1,2)}),
		\fbk, Pfunc({((~lvl * 10000) % 1.0).range(0.1,0.7)}),
		\curve, Pfunc({((~lvl * 10000) % 1.0).range(-1,1)}),
		\shift, Pfunc({((~lvl * 10000) % 1.0).range(-128,128)}),
		\numFrames, Pfunc({((~lvl * 10000) % 1.0).range(10,128)}),
		\phase, Pfunc({((~lvl * 10000) % 1.0).range(-1,1)}),
		\teeth, Pfunc({((~lvl * 10000) % 1.0).range(1,24)}),
		\width, Pfunc({((~lvl * 10000) % 1.0).range(0.1,0.9)}),
		\wipe, Pfunc({((~lvl * 10000) % 1.0).range(0.1,0.9)}),
		\bwr, Pfunc({((~lvl * 10000) % 1.0).range(0.1,5)}),
		\image , Pfunc({((~lvl * 10000) % 1.0).range(-1,1)}),
		\real, Pfunc({((~lvl * 10000) % 1.0).range(-1,1)}),
		\freeze, Pfunc({((~lvl * 10000) % 1.0).range(0,1).round}),
		\pitchDisp, Pfunc({((~lvl * 10000) % 1.0).range(0.001,0.01)}),
		\timeDisp, Pfunc({((~lvl * 10000) % 1.0).range(0.001,0.01)}),
		\threshold, Pfunc({((~lvl * 10000) % 1.0).range(0.1,6)}),
		\low, Pfunc({((~lvl * 10000) % 1.0).range(0.1,0.4)}),
		\band, Pfunc({((~lvl * 10000) % 1.0).range(0.1,0.4)}),
		\high, Pfunc({((~lvl * 10000) % 1.0).range(0.1,0.4)}),
		\notch, Pfunc({((~lvl * 10000) % 1.0).range(0.1,0.4)}),
		\peak, Pfunc({((~lvl * 10000) % 1.0).range(0.1,0.4)}),
		\timeFac, Pfunc({((~lvl * 10000) % 1.0).range(0.5,2)}),
		\atk, Pfunc({((~lvl * 10000) % 1.0).range(5,10)}) * Pkey(\timeFac),
		\sus, Pfunc({((~lvl * 10000) % 1.0).range(20,30)}) * Pkey(\timeFac),
		\rel, Pfunc({((~lvl * 10000) % 1.0).range(5,10)}) * Pkey(\timeFac),
		\dur, 20 * Pkey(\timeFac),
	)
	).play;
	//emerge
};
)