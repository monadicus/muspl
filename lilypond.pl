:- module(lilypond, [export/1]).

/** <module> Lilypond export
*/

:- use_module(data).
:- use_module(theory).

:- ['lilypond.plt'].

%% chord(+Start, -Chord, +Duration)
% True if Chord consisting of _Pitches_, length as Duration starts at Start.
%
% @param Chord (Start, -_Pitches_, Duration)
chord(Start, (Start, Pitches, Duration), Duration) :-
	findall(Pitch, notation(Start, Pitch, Duration), Pitches).

%% chords(+Start, -Chords)
% True if Chords (and nothing else) start at Start.
chords(Start, Chords) :-
	findall(Duration, notation(Start, _, Duration), Durs1),
	sort(Durs1, Durs2),
	maplist(chord(Start), Chords, Durs2).

%% staffLine(+Staff, -Line)
% True if Staff is made of music elements Line.
staffLine(Staff, Line) :-
	allBeats(Staff, Beats),
	maplist(chords, Beats, Chords1),
	flatten(Chords1, Chords2),
	Line = Chords2.

%% pitchLily(+Tone, -Lily)
% True if Tone is represented by Lily string.
%
% @param Tone _|(Pitch, Octave)|_
pitchLily((Pitch, Octave), Lily) :- once((
	Octave > 0, Octave2 is Octave - 1, pitchLily((Pitch, Octave2), Lily2),
		concat(Lily2, '\'', Lily);
	Octave < 0, Octave2 is Octave + 1, pitchLily((Pitch, Octave2), Lily2),
		concat(Lily2, ',', Lily);
	Lily = Pitch)).

%% chordLily(+Chord, -ChordLily)
% True if Chord is represented by ChordLily string.
chordLily(Chord, ChordLily) :- once((
	Chord = (_, Pitches, Duration),
	maplist(pitchLily, Pitches, Pitches2),
	(length(Pitches, 1), [Str] = Pitches2;
		atomic_list_concat(Pitches2, ' ', StrPitches),
		atomic_list_concat(['<', StrPitches, '>'], Str)),
	(number(Duration), atomic_concat(Str, Duration, ChordLily);
		Duration = [Dur1], atomic_concat(Str, Dur1, ChordLily);
		Duration = [Dur1 | DurR], chordLily((_, Pitches, DurR), ChordRLily),
		atomic_list_concat([Str, Dur1, ' ~', ChordRLily], ChordLily))
	)).

%% restLily(+Rest, -RestLily)
% True if Rest is represented by RestLily string.
%
% @param Rest _|(|_=r=_|, Duration)|_ or _|(|_=|[r]|=_|, Duration)|_
restLily((_, Rest, Duration), RestLily) :-
	((Rest == r; Rest == [r]) -> Type = r;
	(Rest == s; Rest == [s]) -> Type = s),
	(number(Duration) -> atomic_concat(Type, Duration, RestLily);
		Duration = [Dur1] -> atomic_concat(Type, Dur1, RestLily);
		Duration = [Dur1 | DurR], restLily((_, Type, DurR), RestRLily),
		atomic_list_concat([Type, Dur1, ' ~', RestRLily], RestLily)).

conflictChords(Chord1, Chord2) :-
	Chord1 \= Chord2,
	Chord1 = (Start1, _, Duration1),
	Chord2 = (Start2, _, _),
	sameStaff(Start1, Start2),
	timeDiff(Start1, Start2, Diff),
	Diff >= 0,
	durationToBeats(Duration1, Beats1),
	Diff < Beats1.

spaceFiller(From, To, Filler) :-
	timeDiff(From, To, Diff),
	beatsToDuration(Diff, Dur),
	Filler = (_, s, Dur).
	

voicesLily(Voices, VoicesLily) :-
	is_list(Voices),
	maplist(itemLily, Voices, VoicesLilies),
	atomic_list_concat(VoicesLilies, ' \\ ', VL2),
	atomic_list_concat(['<<', VL2, '>>\n'], ' ', VoicesLily).

%% itemLily(+Item, -ItemLily)
% True if music element Item is represented by ItemLily string.
%
% @param Item chord or rest
itemLily(Item, ItemLily) :- (chordLily(Item, ItemLily); restLily(Item, ItemLily);
	voicesLily(Item, ItemLily)).

%% staffLily(+Staff, -StaffLily)
% Renders a staff line into a complete Lilypond line.
%
% @param Staff Possible values: =g= or =f=
staffLily(Staff, String) :-
	notationScale((Root, IntervalPattern)),
	timeSignature(BeatsInBar, BeatUnit),
	(Staff == 'g', Clef = 'treble';
		Staff == 'f', Clef = 'bass'),
	atomic_list_concat(['staff', Staff, ' = { \\clef ', Clef, ' \\key ',
		Root, ' \\', IntervalPattern, ' \\time ', BeatsInBar, '/', BeatUnit,
		'\n'], '', Header),
	
	staffLine(Staff, StaffLine),
	maplist(itemLily, StaffLine, LilyItems),
	atomic_list_concat(LilyItems, ' ', LilyLine),
	
	atomic_list_concat([Header, LilyLine, '\n}\n\n'], '', String).

% @tbd empty chord, chord's duration
dbChordQLily(major, 5).
dbChordQLily(minor, m).
dbChordQLily(augmented, aug).
dbChordQLily(diminished, dim).
dbChordQLily(major7, maj7).
dbChordQLily(minor7, m7).
dbChordQLily(majorMinor7, 7).
dbChordQLily(diminished7, dim7).
dbChordQLily(augmented7, aug7).
dbChordQLily(halfDiminished7, 'm7.5-').
dbChordQLily(minorMajor7, 'maj7.5-').
dbChordQLily(major6, 6).
dbChordQLily(minor6, m6).
dbChordQLily(dominant9, 9).
dbChordQLily(major9, maj9).
dbChordQLily(minor9, m9).
dbChordQLily(dominant11, 11).
dbChordQLily(major11, maj11).
dbChordQLily(minor11, m11).
dbChordQLily(dom9maj13, 13).
dbChordQLily(dom11maj13, '13.11').
dbChordQLily(major13, 'maj13.11').
dbChordQLily(minor13, 'm13.11').
dbChordQLily(Quality, Quality).

chordSymLily(Chord, ChordLily) :-
	Duration = 8,

	probSymbolChord(Sym, Chord),
	(Sym == r, ChordLily = 'r8';
	
	Sym = (Root, Quality),
	dbChordQLily(Quality, LilQ), !,
	
	(number(Duration),
		atomic_list_concat([Root, Duration, ':', LilQ], ChordLily);
		Duration = [Dur1],
			atomic_list_concat([Root, Dur1, ':', LilQ], ChordLily);
		Duration = [Dur1 | DurR], chordSymLily((_Pitches, DurR), ChordRLily),
			atomic_list_concat([Root, Dur1, ':', LilQ, ' ~', ChordRLily],
				ChordLily)
	)), !.
chordSymLily(_Chord, '').
	
symbolChordsLily(String) :-
	allSongChords(Chords),
	maplist(chordSymLily, Chords, Lilies),
	atomic_list_concat(Lilies, ' ', LiliesStr),
	atomic_list_concat(['symChords = \\chordmode { ', LiliesStr, ' }\n\n'],
		String).

%% export(+Filename)
% Exports notation into a Lilypond file.
export(Filename) :-
	open(Filename, write, File),
	write(File, '\\version "2.16.1"\n\n'),
	symbolChordsLily(SymChords),
	write(File, SymChords),
	staffLily(g, StaffG),
	write(File, StaffG),
	staffLily(f, StaffF),
	write(File, StaffF),
	write(File, '\\score { <<\n'),
	write(File, '\\new ChordNames \\symChords\n'),
	write(File, '\\new PianoStaff << '),
	write(File, '\\new Staff \\staffg '),
	write(File, '\\new Staff \\stafff >>'),
	write(File, '\n>>\n\\layout { }\n\\midi { }\n}\n'),
	close(File), !.

