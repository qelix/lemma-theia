/**
 * generated by Xtext 2.16.0
 */
package de.fhdo.lemma.operationdsl.ide;

import com.google.inject.Guice;
import com.google.inject.Injector;
import de.fhdo.lemma.operationdsl.OperationDslRuntimeModule;
import de.fhdo.lemma.operationdsl.OperationDslStandaloneSetup;
import org.eclipse.xtext.util.Modules2;

/**
 * Initialization support for running Xtext languages as language servers.
 */
@SuppressWarnings("all")
public class OperationDslIdeSetup extends OperationDslStandaloneSetup {
  @Override
  public Injector createInjector() {
    OperationDslRuntimeModule _operationDslRuntimeModule = new OperationDslRuntimeModule();
    OperationDslIdeModule _operationDslIdeModule = new OperationDslIdeModule();
    return Guice.createInjector(Modules2.mixin(_operationDslRuntimeModule, _operationDslIdeModule));
  }
}
