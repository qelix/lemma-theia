/**
 * generated by Xtext 2.12.0
 */
package de.fhdo.lemma.technology.mappingdsl.tests;

import com.google.inject.Inject;
import de.fhdo.lemma.technology.mapping.TechnologyMapping;
import org.eclipse.xtext.testing.InjectWith;
import org.eclipse.xtext.testing.XtextRunner;
import org.eclipse.xtext.testing.util.ParseHelper;
import org.junit.Test;
import org.junit.runner.RunWith;

@RunWith(XtextRunner.class)
@InjectWith(MappingDslInjectorProvider.class)
@SuppressWarnings("all")
public class MappingDslParsingTest {
  @Inject
  private ParseHelper<TechnologyMapping> parseHelper;
  
  @Test
  public void loadModel() {
  }
}
