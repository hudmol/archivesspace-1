package org.archivesspace.solr;

import java.io.IOException;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.apache.lucene.analysis.TokenFilter;
import org.apache.lucene.analysis.TokenStream;
import org.apache.lucene.analysis.util.TokenFilterFactory;
import org.apache.lucene.util.Version;

import org.apache.lucene.analysis.tokenattributes.PositionIncrementAttribute;
import org.apache.lucene.analysis.tokenattributes.CharTermAttribute;


public class ArchivesSpacePunctuationFilterFactory extends TokenFilterFactory {

    public ArchivesSpacePunctuationFilterFactory(Map<String,String> args) {
        super(args);
        if (!args.isEmpty()) {
            throw new IllegalArgumentException("Unknown parameters: " + args);
        }
    }

    @Override
    public TokenStream create(TokenStream input) {
        return new ArchivesSpacePunctuationFilter(input);
    }

    class ArchivesSpacePunctuationFilter extends TokenFilter {
        private final CharTermAttribute termAtt = addAttribute(CharTermAttribute.class);
        private final PositionIncrementAttribute posIncAttribute = addAttribute(PositionIncrementAttribute.class);

        // Tokens that will be added to the stream at the same position as the
        // original token.  For example, treating "isn't" and "isnt" as
        // synonyms for the purposes of searching.
        private Deque<String> synonymTokens = new ArrayDeque<>();

        private Pattern possessivePattern = Pattern.compile(".*'s");
        private Pattern acronymPattern = Pattern.compile("[A-Z][A-Z\\.]+");


        public ArchivesSpacePunctuationFilter(TokenStream input) {
            super(input);
            synonymTokens = new ArrayDeque<String>();
        }

        public ArchivesSpacePunctuationFilter(Version version, TokenStream input) {
            this(input);
        }

        @Override
        public boolean incrementToken() throws IOException {
            if (synonymTokens.size() > 0) {
                // Emit our next synonym at the same position as the original token.
                String token = synonymTokens.removeFirst();

                emitToken(token);
                posIncAttribute.setPositionIncrement(0);
                return true;
            }

            // Otherwise, process the next token from our incoming stream
            if (!input.incrementToken()) {
                // No more tokens, so we're done here.
                return false;
            }

            // Inspect our next token
            final char[] buffer = termAtt.buffer();
            final int bufferLength = termAtt.length();

            String token = new String(buffer, 0, bufferLength);

            // Emit the current token
            emitToken(token);
            posIncAttribute.setPositionIncrement(1);

            // And then load in its permutations to emit those in subsequent calls
            addPermutations(token);

            return true;
        }

        private void addPermutations(String originalToken) {
            if (originalToken.indexOf("'") >= 0) {
                // o'reilly -> oreilly; coyle's -> coyles
                this.synonymTokens.addLast(originalToken.replace("'", ""));
            }

            if (possessivePattern.matcher(originalToken).matches()) {
                // Allow the possessive to be omitted (coyle's -> coyle)
                this.synonymTokens.addLast(originalToken.substring(0, originalToken.length() - 2));
            }

            // I.B.M. -> IBM
            Matcher m = acronymPattern.matcher(originalToken);
            if (m.matches()) {
                this.synonymTokens.addLast(originalToken.replace(".", ""));
            }
        }

        private void emitToken(String token) {
            termAtt.resizeBuffer(token.length());

            final char[] buffer = termAtt.buffer();
            final int bufferLength = termAtt.length();

            for (int i = 0; i < token.length(); i++) {
                buffer[i] = token.charAt(i);
            }

            termAtt.setLength(token.length());
        }
    }
}
