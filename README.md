# YouFLATE
An interactive tool that allows you to DEFLATE (compress) data using your own length-distance pairs, not merely the most efficient ones as is default with DEFLATE.

# Limitations
The resulting data only applies to one block of data ("final block") in "Fixed Huffman codes" mode

# RFC Stuff
Go ahead and skim RFC 1951 regarding the DEFLATE specification for the details: http://www.faqs.org/rfcs/rfc1951.html

# Theory
Even if you didn't read the above, let's give a breif explanation of how the LZ77 algorithm is coded. 

## What's not covered
We won't discuss how the most efficient length-distance pairs are chosen becuase the main point of this tool is for you to chose your own. We also wont explain the Fixed Huffman codes as this is transparent with this tool (the tool handles this part).

## LZ77 "Tokens"
That's just what I'm calling them; tokens. When using this tool, it is best to imagine a list of tokens that can be one of two things: an actual literal character/byte, or a length-distance pair. A length-distance pair defines how many characters/bytes the next peice of data will be (length), and how many bytes backwards these bytes will start at (distance). An example would make this more clear. Say you have the text: "I am deflating for deflations sake" Below will be all the tokens seperated by hyphens:<br>
I- -a-m- -d-e-f-l-a-t-i-n-g- -f-o-r- -7,14-o-n-s- -s-a-k-e

You will see that most of the tokens are just the literal characters of the sentance. You will also see the 7,14 distance pair. This means that what follows will be 7 characters, and go back 14 characters from this point to fetch them. In this case, 7 characters starting at 14 characters ago was 'deflati'. We then continue on with finishing the word with literal tokens of 'ons' to make up the full word of 'deflations'. This is more or less how it works.

### Constraints
Lengths can't be any longer than 258. You can also not pick a length smaller than 3. Distances can range from 1-32,768 characters/bytes.

## One other trick
This is legitimately part of the specification (at the end of 3.2.3 in RFC 1951). This is regarding when the length is larger than the distance back. Consider you pick a length of 3 and a distance of 1. So you're only going back one byte, this would mean there is only one byte available. What happens in a case like this is that that last byte repeats 3 times. This trick generalizes with larger values as well. Another example will make this clear. Say you have the literals "12345" and then you have the length distance pair of 7,2. This means go back two characters and repeat them for 7 characters worth. So that length distance pair would represent 4545454. Notice it doesn't have to be a nice divisible by 2 boundary. So the final output would be 123454545454

## Interesting Side Note
DEFLATE doesn't always pick the length distnance pairs that give the smallest output (though it almost always does). Here's an example of when it doesn't.
If you were to compress 121212, DEFLATE prefers to do 3 literal characters of '121', and then a length distance pair of 3,2. This is certainly one way of using the 3.2.3 specification behaviour. The resulting compressed data would be the following 6 bytes (in hex) 333432044200.<br><br>

Another way to encode this could be to do 2 literal characters of '12' and then a length distance pair of 4,2. This is interestingly only 5 bytes compressed (in hex) 3334024100.<br><br>

The point of this tool isn't to get better compression, however. That use case just ins't practical; the default LZ77 is usually going to be more 'clever' than us, certainly me (with the exception of the above example). The main use-case is to have different representations of compressed data that decompress (inflate) to identical data using the same algorithm and same arguments.

# Tool usage
This is an interactive tool that prompts you for one token at a time. If it doesn't recogize the token format, it wont record it and will just prompt for the next one. There are 4 token formats: literal, hex escaped literal, a length-distance pair, and an end-of-data token. After a token is typed, you then hit enter/return to be prompted for the next token. While typing the tokens, the tool will also show progress of your data so far. This includes what the final string/data will look like, what the current tokens have been (using different colors for clarity), and what the hex and base64 representations would be.

## Literals
Here are some examples of literals<br>
A<br>
x<br>
D<br>

## Hex escaped literals
Examples of hex escaped literals (hex values prefixed with \x)<br>
\x20<br>
\xff<br>
\xC0<br>

## Length Distance pairs
Examples of length distance pairs (two integers seperated by a comma, no spaces)<br>
3,20<br>
4,2<br>
258,32768<br>

## End Of Data
This is simply just the string of EOF.<br>
