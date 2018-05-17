#!/usr/bin/perl
use warnings;
use strict;
use MIME::Base64;
use Term::ANSIColor;
use Compress::Zlib;

my $header = '011';
my $stopcode = '000000';

my @tokens;
my @readable_tokens = '';
my $hex_bytes = '';
my $base64_data = '';

my $token_count = 0;
my $input = 0;

my ($deflated,$inflator,$buf);

while () {
	system('clear');	#system('cls') on windows
	#Display the current tokens
	print "Current Tokens: ";
	foreach my $token (@readable_tokens) {
		if ($token =~ /^.$/) {
			print color('bright_white on_bright_black');
			print "$token";
			print color('reset');			
		}
		if ($token =~ /^\\x..$/) {
			print color('bright_green on_blue');
			print "$token";
			print color('reset');			
		}
		if ($token =~ /^\d+,\d+$/) {
			print color('red on_green');
			print "$token ";
			print color('reset');			
		}		
	}
	#Display current HEX data and Base64 representation
	print "\nASCIIHex Data: $hex_bytes\n";
	print "Base64: $base64_data";

	# Show what uncompressed string should look like
	$deflated = decode_base64($base64_data);
	$inflator = inflateInit( -WindowBits => -&MAX_WBITS);
	$buf = '';
	while ($deflated) {
	    $buf .= $inflator->inflate($deflated);
	}
	print "Uncompressed data: " . $buf . "\n";

	#Get next token
	print "Next Token: ";
	$input = <STDIN>;
	chomp($input);

	#Store the token in the readables array
	@readable_tokens = (@readable_tokens, $input);
	last if $input eq "EOF";

	#If it's an unescaped literal
	if ($input =~ /^(.)$/) {
		my $charnum = hex(unpack "H*", $1);
		huffman1($charnum);
	}

	#If Input is hex escaped (still a literal)
	if ($input =~ /^\\x(..)$/) {
		print "Literal " . hex($1) . "\n";
		if (hex($1) < 144) {
			huffman1(hex($1));
		} else {
			huffman2(hex($1));
		}
	}

	#If Input is a length,distance pair
	#Max Length: 258, Max Dist: 32768
	if ($input =~ /^(\d+),(\d+)$/) {
		my $length = $1;
		my $dist = $2;

		#sanity checks
		if ($length > 258) {
			print "Length was over 258; too high\n";
			next;
		}
		if ($length < 3) {
			print "Length was under 3; too low\n";
			next
		}
		if ($dist > 32768) {
			print "Distance was over 32768; too high\n";
			next;
		}
		if ($dist < 1) {
			print "Distance must be at least over 1\n";
		}

		if ($length < 115) {
			huffman3($length,$dist);
		} else {
			huffman4($length,$dist);
		}
	}

	$token_count++;
	process_data();
}

process_data();
#Print out The Final version of the resulting "compressed" data
system('clear');	#system('cls') on windows
#Display the current tokens
print "All Tokens: ";
foreach my $token (@readable_tokens) {
	if ($token =~ /^.$/) {
		print color('bright_white on_bright_black');
		print "$token";
		print color('reset');			
	}
	if ($token =~ /^\\x..$/) {
		print color('bright_green on_blue');
		print "$token";
		print color('reset');			
	}
	if ($token =~ /^\d+,\d+$/) {
		print color('red on_green');
		print "$token ";
		print color('reset');			
	}		
}
#Display current HEX data and Base64 representation
print "\nFinal ASCIIHex Data: $hex_bytes\n";
print "Final Base64: $base64_data\n";

# Show what uncompressed string should look like
$deflated = decode_base64($base64_data);
$inflator = inflateInit( -WindowBits => -&MAX_WBITS);
$buf = '';
while ($deflated) {
    $buf .= $inflator->inflate($deflated);
}
print "Final uncompressed data: " . $buf . "\n";

sub process_data {
	#Backup Variables
	my @tokens_b = @tokens;

	#Finish the bit stream with the stop code
	$tokens[$token_count] = $stopcode;

	#All of the data in order
	my $bin_data = join('', @tokens);

	#Properly Reverse all of the bits byte by byte (not straighforward due to alignment)
	my @reversed_bytes;
	#parse first 5 bits
	if ($bin_data =~ /^(.)(.)(.)(.)(.)/) {
		$reversed_bytes[0] = "$5$4$3$2$1$header";		#First byte of 'deflate'
		$bin_data =~ s/^.{5}//;						#remove first 5 bits from buffer
	}
	my $deflate_count = 1;
	while ($bin_data) {
		if ($bin_data =~ /^(.)(.)(.)(.)(.)(.)(.)(.)/) {
			$reversed_bytes[$deflate_count] = "$8$7$6$5$4$3$2$1";
			$bin_data =~ s/^.{8}//;
		} elsif ($bin_data =~ /^(.)(.)(.)(.)(.)(.)(.)/) {
			$reversed_bytes[$deflate_count] = "$7$6$5$4$3$2$1" . "0";
			$bin_data =~ s/^.{7}//;	
		} elsif ($bin_data =~ /^(.)(.)(.)(.)(.)(.)/) {
			$reversed_bytes[$deflate_count] = "$6$5$4$3$2$1" . "00";
			$bin_data =~ s/^.{6}//;	
		} elsif ($bin_data =~ /^(.)(.)(.)(.)(.)/) {
			$reversed_bytes[$deflate_count] = "$5$4$3$2$1" . "000";
			$bin_data =~ s/^.{5}//;		
		} elsif ($bin_data =~ /^(.)(.)(.)(.)/) {
			$reversed_bytes[$deflate_count] = "$4$3$2$1" . "0000";
			$bin_data =~ s/^.{4}//;	
		} elsif ($bin_data =~ /^(.)(.)(.)/) {
			$reversed_bytes[$deflate_count] = "$3$2$1" . "00000";
			$bin_data =~ s/^.{3}//;									
		} elsif ($bin_data =~ /^(.)(.)/) {
			$reversed_bytes[$deflate_count] = "$2$1" . "000000";
			$bin_data =~ s/^.{2}//;	
		} elsif ($bin_data =~ /^(.)/) {
			$reversed_bytes[$deflate_count] = "$1" . "0000000";
			$bin_data =~ s/^.{1}//;	
		}
		$deflate_count++;
	}

	#If you want to see the binary
	#print @reversed_bytes;

	#print hex form of bytes
	$hex_bytes = '';		#init hex bytes
	my $deflate_data;
	foreach my $byte (@reversed_bytes){
		$byte = sprintf('%.2X', oct("0b$byte"));
		$hex_bytes .= "$byte";
		$deflate_data .= pack("C*", map {$_ ? hex($_) :()} $byte);
	}

	$base64_data = encode_base64($deflate_data);

	@tokens = @tokens_b;
}

sub huffman1 {
	my $number = shift;
	$number += 48;						#Adjust for huffman range
	$number = sprintf("%#.8b",$number);	#Convert to binary
	$number =~ s/^0b//;					#Remove '0b' prefix
	$tokens[$token_count] = $number;
}

sub huffman2 {
	my $number = shift;
	$number += 256;						#Adjust for huffman range
	$number = sprintf("%#.9b",$number);	#Convert to binary
	$number =~ s/^0b//;					#Remove '0b' prefix
	$tokens[$token_count] = $number;
}

#7-bit huffman code + extra length bits (reverse) + 5-bit distance code + extra distance bits (reverse)
sub huffman3 {
	my $length = shift;
	my $dist = shift;
	my $extra1 = "";
	my $extra2 = "";

	#Get Binary for length and extra bits
	if (($length > 2) && ($length < 11)) { 
		$length -= 2; #No extra bits required for this
		$length = sprintf("%#.7b",$length);	#Convert to binary
		$length =~ s/^0b//;
	} elsif (($length > 10) && ($length < 13)) { 
		$extra1 = 12 - $length;		#Get in the right range
		$extra1 = 1 - $extra1;		#easier than reversing the binary afterwards
		$extra1 = sprintf("%#.1b",$extra1);	#Convert to binary
		$extra1 =~ s/^0b//;		
		$length = "0001001";
	} elsif (($length > 12) && ($length < 15)) { 
		$extra1 = 14 - $length;		#Get in the right range
		$extra1 = 1 - $extra1;		#easier than reversing the binary afterwards
		$extra1 = sprintf("%#.1b",$extra1);	#Convert to binary
		$extra1 =~ s/^0b//;		
		$length = "0001010";
	} elsif (($length > 14) && ($length < 17)) { 
		$extra1 = 16 - $length;		#Get in the right range
		$extra1 = 1 - $extra1;		#easier than reversing the binary afterwards
		$extra1 = sprintf("%#.1b",$extra1);	#Convert to binary
		$extra1 =~ s/^0b//;		
		$length = "0001011";	
	} elsif (($length > 16) && ($length < 19)) { 
		$extra1 = 18 - $length;		#Get in the right range
		$extra1 = 1 - $extra1;		#easier than reversing the binary afterwards
		$extra1 = sprintf("%#.1b",$extra1);	#Convert to binary
		$extra1 =~ s/^0b//;		
		$length = "0001100";	
	} elsif (($length > 18) && ($length < 23)) { 
		$extra1 = $length - 19;		#Get in the right range
		$extra1 = sprintf("%#.2b",$extra1);	#Convert to binary
		$extra1 =~ s/^0b//;		
		$extra1 = reverse($extra1);
		$length = "0001101";	
	} elsif (($length > 22) && ($length < 27)) { 
		$extra1 = $length - 23;		#Get in the right range
		$extra1 = sprintf("%#.2b",$extra1);	#Convert to binary
		$extra1 =~ s/^0b//;		
		$extra1 = reverse($extra1);
		$length = "0001110";	
	} elsif (($length > 26) && ($length < 31)) { 
		$extra1 = $length - 27;		#Get in the right range
		$extra1 = sprintf("%#.2b",$extra1);	#Convert to binary
		$extra1 =~ s/^0b//;		
		$extra1 = reverse($extra1);
		$length = "0001111";
	} elsif (($length > 30) && ($length < 35)) { 
		$extra1 = $length - 31;		#Get in the right range
		$extra1 = sprintf("%#.2b",$extra1);	#Convert to binary
		$extra1 =~ s/^0b//;		
		$extra1 = reverse($extra1);
		$length = "0010000";
	} elsif (($length > 34) && ($length < 43)) { 
		$extra1 = $length - 35;		#Get in the right range
		$extra1 = sprintf("%#.3b",$extra1);	#Convert to binary
		$extra1 =~ s/^0b//;		
		$extra1 = reverse($extra1);
		$length = "0010001";
	} elsif (($length > 42) && ($length < 51)) { 
		$extra1 = $length - 43;		#Get in the right range
		$extra1 = sprintf("%#.3b",$extra1);	#Convert to binary
		$extra1 =~ s/^0b//;		
		$extra1 = reverse($extra1);
		$length = "0010010";	
	} elsif (($length > 50) && ($length < 59)) { 
		$extra1 = $length - 51;		#Get in the right range
		$extra1 = sprintf("%#.3b",$extra1);	#Convert to binary
		$extra1 =~ s/^0b//;		
		$extra1 = reverse($extra1);
		$length = "0010011";	
	} elsif (($length > 58) && ($length < 67)) { 
		$extra1 = $length - 59;		#Get in the right range
		$extra1 = sprintf("%#.3b",$extra1);	#Convert to binary
		$extra1 =~ s/^0b//;		
		$extra1 = reverse($extra1);
		$length = "0010100";
	} elsif (($length > 66) && ($length < 83)) { 
		$extra1 = $length - 67;		#Get in the right range
		$extra1 = sprintf("%#.4b",$extra1);	#Convert to binary
		$extra1 =~ s/^0b//;		
		$extra1 = reverse($extra1);
		$length = "0010101";
	} elsif (($length > 82) && ($length < 99)) { 
		$extra1 = $length - 83;		#Get in the right range
		$extra1 = sprintf("%#.4b",$extra1);	#Convert to binary
		$extra1 =~ s/^0b//;		
		$extra1 = reverse($extra1);
		$length = "0010110";	
	} elsif (($length > 98) && ($length < 115)) { 
		$extra1 = $length - 99;		#Get in the right range
		$extra1 = sprintf("%#.4b",$extra1);	#Convert to binary
		$extra1 =~ s/^0b//;		
		$extra1 = reverse($extra1);
		$length = "0010111";
	}

	#outsource distance values
	($dist, $extra2) = distance($dist);

	$tokens[$token_count] = "$length" . "$extra1" . "$dist" . "$extra2";	
}

sub huffman4 {
	my $length = shift;
	my $dist = shift;
	my $extra1;
	my $extra2;

	#Get Binary for length and extra bits
	if (($length > 114) && ($length < 131)) { 
		$extra1 = $length - 115;		#Get in the right range
		$extra1 = sprintf("%#.4b",$extra1);	#Convert to binary
		$extra1 =~ s/^0b//;		
		$extra1 = reverse($extra1);
		$length = "11000000";	
	} elsif (($length > 130) && ($length < 163)) { 
		$extra1 = $length - 131;		#Get in the right range
		$extra1 = sprintf("%#.5b",$extra1);	#Convert to binary
		$extra1 =~ s/^0b//;		
		$extra1 = reverse($extra1);
		$length = "11000001";
	} elsif (($length > 162) && ($length < 195)) { 
		$extra1 = $length - 163;		#Get in the right range
		$extra1 = sprintf("%#.5b",$extra1);	#Convert to binary
		$extra1 =~ s/^0b//;		
		$extra1 = reverse($extra1);
		$length = "11000010";	
	} elsif (($length > 194) && ($length < 227)) { 
		$extra1 = $length - 195;		#Get in the right range
		$extra1 = sprintf("%#.5b",$extra1);	#Convert to binary
		$extra1 =~ s/^0b//;		
		$extra1 = reverse($extra1);
		$length = "11000011";	
	} elsif (($length > 226) && ($length < 258)) { 
		$extra1 = $length - 227;		#Get in the right range
		$extra1 = sprintf("%#.5b",$extra1);	#Convert to binary
		$extra1 =~ s/^0b//;		
		$extra1 = reverse($extra1);
		$length = "11000100";	
	} else {
		$length = "11000101";			
	}

	#outsource distance values
	($dist, $extra2) = distance($dist);

	$tokens[$token_count] = "$length" . "$extra1" . "$dist" . "$extra2";
}

sub distance {
	my $dist = shift;
	my $extra = "";
	if ($dist == 1) {
		$dist = "00000";
	} elsif ($dist == 2) {
		$dist = "00001";
	} elsif ($dist == 3) {
		$dist = "00010";
	} elsif ($dist == 4) {
		$dist = "00011";
	} elsif (($dist > 4) && ($dist < 7)) { 
		$extra = 6 - $dist;		#Get in the right range
		$extra = 1 - $extra;		#easier than reversing the binary afterwards
		$extra = sprintf("%#.1b",$extra);	#Convert to binary
		$extra =~ s/^0b//;		
		$dist = "00100";	
	} elsif (($dist > 6) && ($dist < 9)) { 
		$extra = 8 - $dist;		#Get in the right range
		$extra = 1 - $extra;		#easier than reversing the binary afterwards
		$extra = sprintf("%#.1b",$extra);	#Convert to binary
		$extra =~ s/^0b//;		
		$dist = "00101";	
	} elsif (($dist > 8) && ($dist < 13)) { 
		$extra = $dist - 9;		#Get in the right range
		$extra = sprintf("%#.2b",$extra);	#Convert to binary
		$extra =~ s/^0b//;		
		$extra = reverse($extra);
		$dist = "00110";
	} elsif (($dist > 12) && ($dist < 17)) { 
		$extra = $dist - 13;		#Get in the right range
		$extra = sprintf("%#.2b",$extra);	#Convert to binary
		$extra =~ s/^0b//;		
		$extra = reverse($extra);
		$dist = "00111";	
	} elsif (($dist > 16) && ($dist < 25)) { 
		$extra = $dist - 17;		#Get in the right range
		$extra = sprintf("%#.3b",$extra);	#Convert to binary
		$extra =~ s/^0b//;		
		$extra = reverse($extra);
		$dist = "01000";	
	} elsif (($dist > 24) && ($dist < 33)) { 
		$extra = $dist - 25;		#Get in the right range
		$extra = sprintf("%#.3b",$extra);	#Convert to binary
		$extra =~ s/^0b//;		
		$extra = reverse($extra);
		$dist = "01001";	
	} elsif (($dist > 32) && ($dist < 49)) { 
		$extra = $dist - 33;		#Get in the right range
		$extra = sprintf("%#.4b",$extra);	#Convert to binary
		$extra =~ s/^0b//;		
		$extra = reverse($extra);
		$dist = "01010";
	} elsif (($dist > 48) && ($dist < 65)) { 
		$extra = $dist - 49;		#Get in the right range
		$extra = sprintf("%#.4b",$extra);	#Convert to binary
		$extra =~ s/^0b//;		
		$extra = reverse($extra);
		$dist = "01011";	
	} elsif (($dist > 64) && ($dist < 97)) { 
		$extra = $dist - 65;		#Get in the right range
		$extra = sprintf("%#.5b",$extra);	#Convert to binary
		$extra =~ s/^0b//;		
		$extra = reverse($extra);
		$dist = "01100";
	} elsif (($dist > 96) && ($dist < 129)) { 
		$extra = $dist - 97;		#Get in the right range
		$extra = sprintf("%#.5b",$extra);	#Convert to binary
		$extra =~ s/^0b//;		
		$extra = reverse($extra);
		$dist = "01101";
	} elsif (($dist > 128) && ($dist < 193)) { 
		$extra = $dist - 129;		#Get in the right range
		$extra = sprintf("%#.6b",$extra);	#Convert to binary
		$extra =~ s/^0b//;		
		$extra = reverse($extra);
		$dist = "01110";
	} elsif (($dist > 192) && ($dist < 257)) { 
		$extra = $dist - 193;		#Get in the right range
		$extra = sprintf("%#.6b",$extra);	#Convert to binary
		$extra =~ s/^0b//;		
		$extra = reverse($extra);
		$dist = "01111";	
	} elsif (($dist > 256) && ($dist < 385)) { 
		$extra = $dist - 257;		#Get in the right range
		$extra = sprintf("%#.7b",$extra);	#Convert to binary
		$extra =~ s/^0b//;		
		$extra = reverse($extra);
		$dist = "10000";	
	} elsif (($dist > 384) && ($dist < 513)) { 
		$extra = $dist - 385;		#Get in the right range
		$extra = sprintf("%#.7b",$extra);	#Convert to binary
		$extra =~ s/^0b//;		
		$extra = reverse($extra);
		$dist = "10001";	
	} elsif (($dist > 512) && ($dist < 769)) { 
		$extra = $dist - 513;		#Get in the right range
		$extra = sprintf("%#.8b",$extra);	#Convert to binary
		$extra =~ s/^0b//;		
		$extra = reverse($extra);
		$dist = "10010";
	} elsif (($dist > 768) && ($dist < 1025)) { 
		$extra = $dist - 769;		#Get in the right range
		$extra = sprintf("%#.8b",$extra);	#Convert to binary
		$extra =~ s/^0b//;		
		$extra = reverse($extra);
		$dist = "10011";	
	} elsif (($dist > 1024) && ($dist < 1537)) { 
		$extra = $dist - 1025;		#Get in the right range
		$extra = sprintf("%#.9b",$extra);	#Convert to binary
		$extra =~ s/^0b//;		
		$extra = reverse($extra);
		$dist = "10100";	
	} elsif (($dist > 1536) && ($dist < 2049)) { 
		$extra = $dist - 1537;		#Get in the right range
		$extra = sprintf("%#.9b",$extra);	#Convert to binary
		$extra =~ s/^0b//;		
		$extra = reverse($extra);
		$dist = "10101";	
	} elsif (($dist > 2048) && ($dist < 3073)) { 
		$extra = $dist - 2049;		#Get in the right range
		$extra = sprintf("%#.10b",$extra);	#Convert to binary
		$extra =~ s/^0b//;		
		$extra = reverse($extra);
		$dist = "10110";
	} elsif (($dist > 3072) && ($dist < 4097)) { 
		$extra = $dist - 3073;		#Get in the right range
		$extra = sprintf("%#.10b",$extra);	#Convert to binary
		$extra =~ s/^0b//;		
		$extra = reverse($extra);
		$dist = "10111";	
	} elsif (($dist > 4096) && ($dist < 6145)) { 
		$extra = $dist - 4097;		#Get in the right range
		$extra = sprintf("%#.11b",$extra);	#Convert to binary
		$extra =~ s/^0b//;		
		$extra = reverse($extra);
		$dist = "11000";	
	} elsif (($dist > 6144) && ($dist < 8193)) { 
		$extra = $dist - 6145;		#Get in the right range
		$extra = sprintf("%#.11b",$extra);	#Convert to binary
		$extra =~ s/^0b//;		
		$extra = reverse($extra);
		$dist = "11001";
	} elsif (($dist > 8192) && ($dist < 12289)) { 
		$extra = $dist - 8193;		#Get in the right range
		$extra = sprintf("%#.12b",$extra);	#Convert to binary
		$extra =~ s/^0b//;		
		$extra = reverse($extra);
		$dist = "11010";	
	} elsif (($dist > 12288) && ($dist < 16385)) { 
		$extra = $dist - 12289;		#Get in the right range
		$extra = sprintf("%#.12b",$extra);	#Convert to binary
		$extra =~ s/^0b//;		
		$extra = reverse($extra);
		$dist = "11011";
	} elsif (($dist > 16384) && ($dist < 24577)) { 
		$extra = $dist - 16385;		#Get in the right range
		$extra = sprintf("%#.13b",$extra);	#Convert to binary
		$extra =~ s/^0b//;		
		$extra = reverse($extra);
		$dist = "11100";	
	} elsif (($dist > 24574) && ($dist < 32769)) { 
		$extra = $dist - 24575;		#Get in the right range
		$extra = sprintf("%#.13b",$extra);	#Convert to binary
		$extra =~ s/^0b//;		
		$extra = reverse($extra);
		$dist = "11101";	
	}
	return ("$dist", "$extra");
}
