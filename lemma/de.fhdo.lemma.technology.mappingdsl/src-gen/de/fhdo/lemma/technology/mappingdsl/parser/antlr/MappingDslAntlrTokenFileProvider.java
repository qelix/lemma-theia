/*
 * generated by Xtext 2.25.0
 */
package de.fhdo.lemma.technology.mappingdsl.parser.antlr;

import java.io.InputStream;
import org.eclipse.xtext.parser.antlr.IAntlrTokenFileProvider;

public class MappingDslAntlrTokenFileProvider implements IAntlrTokenFileProvider {

	@Override
	public InputStream getAntlrTokenFile() {
		ClassLoader classLoader = getClass().getClassLoader();
		return classLoader.getResourceAsStream("de/fhdo/lemma/technology/mappingdsl/parser/antlr/internal/InternalMappingDsl.tokens");
	}
}