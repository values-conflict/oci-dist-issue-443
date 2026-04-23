#!/usr/bin/perl
# Reformat markdown files to use one-sentence-per-line convention.
#
# Rules:
#   - Inside fenced code blocks (``` or ~~~): preserve verbatim.
#     Closing fence must use >= the same number of backticks as the opener.
#   - Lines that are: blank, headings (#), blockquotes (>), list item bullets,
#     table rows (|), or key-value front-matter (**Name:**) -> preserve verbatim.
#   - Indented continuation lines under list items are gathered into groups.
#     Groups already correctly formatted (every line ends with terminal punctuation)
#     are left verbatim. Groups with mid-sentence wrapping are joined greedily
#     (join where the preceding line lacks terminal punctuation) and re-split at
#     sentence boundaries.
#   - Plain prose lines form paragraphs that are joined and sentence-split.
#
# Sentence boundary = ., !, or ? followed by a space or end-of-input,
#   with optional closing quote/bracket after, EXCEPT:
#     - preceded by a known abbreviation (e.g., "e.g.", "i.e.", "etc.")
#     - preceded by a single-letter initial like "U."
#     - part of a multi-period token like "v2.7.1"
#   - Inside `inline code` backticks and [link text](url) URLs, don't split.

use strict;
use warnings;

my @ABBREVS = (
    "e.g.", "i.e.", "etc.", "cf.", "vs.", "viz.",
    "Mr.", "Mrs.", "Ms.", "Dr.", "St.", "Jr.", "Sr.",
    "No.", "Nos.", "Vol.", "Vols.", "Ch.", "Chs.",
    "Fig.", "Figs.", "Eq.", "Eqs.", "Ref.", "Refs.",
    "Sec.", "Secs.",
    "a.m.", "p.m.", "A.M.", "P.M.",
    "approx.", "Inc.", "Co.", "Ltd.", "Corp.",
    "RFC.",
);
my %ABBREV = map { lc($_) => 1 } @ABBREVS;

sub parse_continuation {
    my ($line) = @_;
    return undef unless $line =~ /^( {2,})(.+)$/;
    my ($indent, $content) = ($1, $2);
    return undef if $content =~ /^[-*+] /;
    return undef if $content =~ /^\d+\. /;
    return undef if $content =~ /^>/;
    return undef if $content =~ /^(```+|~~~+)/;
    return undef if $content =~ /^\|/;
    return ($indent, $content);
}

sub is_prose_line {
    my ($line) = @_;
    return 0 if $line =~ /^\s/;
    return 0 if $line eq "";
    return 0 if $line =~ /^#/;
    return 0 if $line =~ /^>/;
    return 0 if $line =~ /^\|/;
    return 0 if $line =~ /^(```|~~~)/;
    return 0 if $line =~ /^([-*+]\s|\d+\.\s)/;
    return 0 if $line =~ /^\*\*[^*]+:\*\*/;
    return 1;
}

sub looks_like_abbrev {
    my ($tok) = @_;
    return 1 if $tok =~ /^[A-Za-z]\.$/;
    return 1 if exists $ABBREV{lc($tok)};
    return 0;
}

# Does the trimmed content end with terminal punctuation?
# Terminal: ., !, ?, :, backtick, ), ], **
# A trailing abbreviation period (e.g., "e.g.") is NOT terminal.
sub ends_with_terminal {
    my ($s) = @_;
    $s =~ s/\s+$//;
    return 1 if $s eq '';
    return 1 if $s =~ /\*\*$/;
    return 1 if $s =~ /[!?:`)\]]$/;
    if ($s =~ /\.$/) {
        my $tail = $s;
        $tail =~ s/.*\s//;
        my $tok = $tail;
        $tok =~ s/^["'(\[]+//;
        return 0 if looks_like_abbrev($tok);
        return 1;
    }
    return 1 if $s =~ /[.!?]["'\)\]]+$/;
    return 0;
}

sub split_into_sentences {
    my ($text) = @_;
    $text =~ s/\s+/ /g;
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    return () if $text eq "";

    my @sentences;
    my @chars = split //, $text;
    my $n = scalar @chars;
    my $i = 0;
    my $start = 0;
    my $in_code = 0;
    my $code_delim = 0;
    my $bracket_depth = 0;
    my $in_link_url = 0;
    my $paren_depth = 0;

    while ($i < $n) {
        my $c = $chars[$i];

        if ($c eq '`' && !$in_link_url) {
            if (!$in_code) {
                my $j = $i;
                $j++ while $j < $n && $chars[$j] eq '`';
                $code_delim = $j - $i;
                $in_code = 1;
                $i = $j;
            } else {
                my $j = $i;
                $j++ while $j < $n && $chars[$j] eq '`';
                if (($j - $i) == $code_delim) { $in_code = 0; $code_delim = 0; }
                $i = $j;
            }
            next;
        }
        if ($in_code) { $i++; next; }

        if ($c eq '[') { $bracket_depth++; $i++; next; }
        if ($c eq ']') {
            $bracket_depth-- if $bracket_depth > 0;
            if ($i + 1 < $n && $chars[$i+1] eq '(') {
                $in_link_url = 1; $paren_depth = 1; $i += 2; next;
            }
            $i++; next;
        }
        if ($in_link_url) {
            if    ($c eq '(') { $paren_depth++; }
            elsif ($c eq ')') { $paren_depth--; $in_link_url = 0 if $paren_depth == 0; }
            $i++; next;
        }

        if ($c eq '.' || $c eq '!' || $c eq '?') {
            my $j = $i + 1;
            while ($j < $n && $chars[$j] =~ /["')\]]/) { $j++; }
            my $at_end        = ($j >= $n);
            my $next_is_space = ($j < $n && $chars[$j] eq ' ');
            if (!$at_end && !$next_is_space) { $i++; next; }

            if (($c eq '?' || $c eq '!') && $next_is_space && $j > $i + 1) {
                my $k = $j + 1;
                while ($k < $n && $chars[$k] eq ' ') { $k++; }
                if ($k < $n && $chars[$k] =~ /[a-z]/) { $i++; next; }
            }

            if ($c eq '.') {
                my $k = $i;
                while ($k > $start && $chars[$k-1] ne ' ') { $k--; }
                my $prev_token       = join('', @chars[$k..$i]);
                my $token_for_abbrev = $prev_token;
                $token_for_abbrev =~ s/^["'(\[]+//;
                my $body = $prev_token; chop $body;
                if ($body =~ /\./) { $i = $j; next; }
                if (looks_like_abbrev($token_for_abbrev)) { $i = $j; next; }
            }

            my $sentence = join('', @chars[$start..$j-1]);
            $sentence =~ s/^\s+|\s+$//g;
            push @sentences, $sentence if length $sentence;
            while ($j < $n && $chars[$j] eq ' ') { $j++; }
            $start = $j; $i = $j;
            next;
        }
        $i++;
    }

    if ($start < $n) {
        my $tail = join('', @chars[$start..$n-1]);
        $tail =~ s/^\s+|\s+$//g;
        push @sentences, $tail if length $tail;
    }
    return @sentences;
}

sub reformat {
    my ($text) = @_;
    my $had_newline = ($text =~ /\n\z/);
    my @lines = split /\n/, $text, -1;
    if ($had_newline && @lines && $lines[-1] eq '') { pop @lines; }

    my @out;
    my $in_fence   = 0;
    my $fence_char = '';
    my $fence_min  = 0;
    my $i = 0;
    my $n = scalar @lines;

    OUTER: while ($i < $n) {
        my $line = $lines[$i];

        # ── Fence handling ───────────────────────────────────────────────────
        if (!$in_fence) {
            if ($line =~ /^\s*((`{3,}|~{3,}))/) {
                my $marker = $1;
                $fence_char = substr($marker, 0, 1);
                $fence_min  = length($marker);
                $in_fence = 1;
                push @out, $line; $i++; next;
            }
        } else {
            push @out, $line;
            if ($line =~ /^\s*(\Q$fence_char\E+)\s*$/ && length($1) >= $fence_min) {
                $in_fence = 0; $fence_char = ''; $fence_min = 0;
            }
            $i++; next;
        }

        # ── Plain prose lines ─────────────────────────────────────────────────
        if (is_prose_line($line)) {
            my @para = ($line);
            my $j = $i + 1;
            while ($j < $n) {
                my $nl = $lines[$j];
                last if $nl =~ /^\s*$/;
                last if !is_prose_line($nl);
                last if $nl =~ /^\s*(```+|~~~+)/;
                push @para, $nl;
                $j++;
            }
            my $joined = join(' ', map { (my $s = $_) =~ s/^\s+|\s+$//g; $s } @para);
            my @sents  = split_into_sentences($joined);
            push @out, (@sents ? @sents : @para);
            $i = $j; next;
        }

        # ── Indented continuation lines ───────────────────────────────────────
        {
            my ($indent, $content) = parse_continuation($line);
            if (defined $indent) {
                # Collect all consecutive lines with the same indent.
                my @para = ($content);
                my $j = $i + 1;
                while ($j < $n) {
                    my $nl = $lines[$j];
                    last if $nl =~ /^\s*$/;
                    my ($ni, $nc) = parse_continuation($nl);
                    last unless defined $ni && $ni eq $indent;
                    push @para, $nc;
                    $j++;
                }

                if (@para == 1) {
                    # Single line — no joining needed.
                    push @out, $line;
                    $i++; next OUTER;
                }

                # Check if any line (except the last) lacks terminal punctuation.
                my $any_wrapped = 0;
                for my $k (0 .. $#para - 1) {
                    if (!ends_with_terminal($para[$k])) { $any_wrapped = 1; last; }
                }

                if (!$any_wrapped) {
                    # Already one-sentence-per-line — keep verbatim.
                    push @out, map { "$indent$_" } @para;
                    $i = $j; next OUTER;
                }

                # Greedy join: merge line into the next when it lacks terminal punctuation.
                my @blocks;
                my $cur = $para[0];
                for my $k (1 .. $#para) {
                    if (!ends_with_terminal($cur)) {
                        $cur = $cur . ' ' . $para[$k];
                    } else {
                        push @blocks, $cur;
                        $cur = $para[$k];
                    }
                }
                push @blocks, $cur;

                # Split each block at internal sentence boundaries.
                my @result;
                for my $block (@blocks) {
                    my @sents = split_into_sentences($block);
                    push @result, (@sents ? @sents : $block);
                }
                push @out, map { "$indent$_" } @result;
                $i = $j; next OUTER;
            }
        }

        # ── List-item header overflow ─────────────────────────────────────────
        # When a list-item line doesn't end its first sentence, join it with the
        # indented continuation block and sentence-split the whole thing.
        if ($line =~ /^(([-*+]|\d+\.)\s+)(.+)$/) {
            my ($prefix, undef, $content) = ($1, $2, $3);
            my $indent = ' ' x length($prefix);
            if (!ends_with_terminal($content)) {
                my @cont;
                my $j = $i + 1;
                while ($j < $n) {
                    my $nl = $lines[$j];
                    last if $nl =~ /^\s*$/;
                    my ($ni, $nc) = parse_continuation($nl);
                    last unless defined $ni && $ni eq $indent;
                    push @cont, $nc;
                    $j++;
                }
                if (@cont) {
                    my $full = join(' ', $content, @cont);
                    $full =~ s/\s+/ /g;
                    my @sents = split_into_sentences($full);
                    if (@sents > 1) {
                        push @out, $prefix . shift(@sents);
                        push @out, map { "$indent$_" } @sents;
                        $i = $j; next OUTER;
                    }
                }
            }
        }

        # ── Verbatim fallthrough ──────────────────────────────────────────────
        push @out, $line;
        $i++;
    }

    my $result = join("\n", @out);
    $result .= "\n" if $had_newline;
    return $result;
}

for my $path (@ARGV) {
    open(my $fh, '<', $path) or die "cannot read $path: $!";
    local $/;
    my $content = <$fh>;
    close $fh;
    my $new = reformat($content);
    if ($new ne $content) {
        open(my $out, '>', $path) or die "cannot write $path: $!";
        print $out $new;
        close $out;
        print "Updated: $path\n";
    } else {
        print "No change: $path\n";
    }
}
