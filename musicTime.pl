:- module(musicTime, [
	simpleTime/2,
	timeDiff/3,
	timeAdd/3,
	durationToBeats/2,
	beatsToDuration/2,
	normalizedDuration/2,
	addDurations/3,
	dursInvCmp/3,
	allSongChords/1,
	allSymbChordsWithDur/1
	]).

:- use_module(aux).
:- use_module(data).
:- use_module(symbolChords).

:- ['musicTime.plt'].

simpleTime(Time, (Bar, Beat)) :-
	once((Time = (Bar, Beat, _Staff);
		Time = (Bar, Beat))).

%% timeDiff(+Time1, +Time2, -Diff)
% True if Time2 - Time1 = Diff in beats.
timeDiff(Time1, Time2, Diff) :-
	simpleTime(Time1, (Measure1, Beat1)),
	simpleTime(Time2, (Measure2, Beat2)),
	once(extra timeSignature(BeatsPerMeasure, _)),
	Diff is (Measure2 - Measure1) * BeatsPerMeasure + Beat2 - Beat1.

timeAdd(Time1, Dur, Time2) :-
	Time1 = (Measure1, Beat1, Staff),
	once(extra timeSignature(BeatsPerMeasure, _)),
	durationToBeats(Dur, BeatsAdded),
	BeatAdded is Beat1 - 1 + BeatsAdded,
	Measure2 is Measure1 + floor(BeatAdded) div BeatsPerMeasure,
	Beat2 is floor(BeatAdded) mod BeatsPerMeasure + 1 +
		float_fractional_part(BeatAdded),
	Time2 = (Measure2, Beat2, Staff).
	

%% durationToBeats(+Duration, -Beats)
% True if Duration(s) take Beats of beats.
durationToBeats(Duration, Beats) :-
	number(Duration),
	extra timeSignature(_, NoteDuration),
	Beats is NoteDuration / Duration.
durationToBeats([], 0).
durationToBeats([Duration | Rest], Beats) :-
	durationToBeats(Duration, Beat1),
	durationToBeats(Rest, BeatsR),
	Beats is Beat1 + BeatsR.

beatsToDuration(Beats, Duration) :-
	number(Beats), Beats > 0,
	extra timeSignature(_, NoteDuration),
	FloatDuration is NoteDuration / Beats,
	normalizedDuration(FloatDuration, Duration).

normalizedDuration(Duration, Normalized) :-
	(Duration > 128; Duration < 10 * epsilon) -> Normalized = [];
	
	NormDur is max(2 ** ceiling(log(Duration) / log(2)), 1),
	(NormDur =:= Duration -> Normalized = [NormDur];
		DurRest is 1 / (1 / Duration - 1 / NormDur),
		normalizedDuration(DurRest, NormRest),
		Normalized = [NormDur | NormRest]).

durationDiff(Time1, Time2, Diff) :-
	timeDiff(Time1, Time2, TimeDiff),
	beatsToDuration(TimeDiff, Diff).

sumDurationsInv(Durs, Sum) :-
	map_list(inverse, Durs, Invs),
	sum_list(Invs, Sum).

addDurations(Dur1, Dur2, Dur) :-
	sumDurationsInv(Dur1, SumInvDur1),
	sumDurationsInv(Dur2, SumInvDur2),
	DurSum is 1 / (SumInvDur1 + SumInvDur2),
	normalizedDuration(DurSum, Dur).

dursInvCmp(Delta, Durs1, Durs2) :-
	sumDurationsInv(Durs1, Sum1),
	sumDurationsInv(Durs2, Sum2),
	compare(Delta, Sum2, Sum1).

%% toneAtTime(-Tone, +Time)
% True if Tone sounds at Time.
toneAtTime(Tone, Time) :-
	notation(Time2, Tone, Duration),
	timeDiff(Time2, Time, Diff),
	Diff >= 0,
	durationToBeats(Duration, Beats),
	Diff < Beats.

%% chordAtTime(-Chord, +Time)
% True if Chord (and no more tones) sound at Time.
chordAtTime(Chord, Time) :-
	findall(Tone, toneAtTime(Tone, Time), Chord).

first((A, _), A).
afterEndBeat(EndBeat) :-
	allBeats(Beats),
	maplist(first, Beats, Measures),
	max_list(Measures, MaxMeasure),
	
	once(extra timeSignature(BeatsPerMeasure, _)),
	AfterBeat is BeatsPerMeasure + 1,
	
	EndBeat = (MaxMeasure, AfterBeat).

%% allSongChords(-Chords)
% Returns all song's chords as they follow.
allSongChords(Chords) :-
	allBeats(Beats),
	maplist(chordAtTime, Chords, Beats).
allSymbChordsWithDur(DurSymbChords) :-
	allBeats(Beats),
	
	afterEndBeat(EndBeat),
	append(Beats, [EndBeat], NextBeats),
	maplist(durationDiff, [(1, 0) | Beats], NextBeats, Durs1),
	Durs1 = [_ | Durs],

	maplist(chordAtTime, Chords, Beats),
	maplist(probSymbolChord, SymbChords, Chords),
	maplist(zip, SymbChords, Durs, DurSymbChords).
zip(A, B, (A, B)).

