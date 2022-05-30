/**
 * generated by Xtext 2.12.0
 */
package de.fhdo.lemma.ide;

import com.google.inject.Guice;
import com.google.inject.Injector;
import de.fhdo.lemma.ServiceDslRuntimeModule;
import de.fhdo.lemma.ServiceDslStandaloneSetup;
import org.eclipse.xtext.util.Modules2;

/**
 * Initialization support for running Xtext languages as language servers.
 */
@SuppressWarnings("all")
public class ServiceDslIdeSetup extends ServiceDslStandaloneSetup {
  @Override
  public Injector createInjector() {
    ServiceDslRuntimeModule _serviceDslRuntimeModule = new ServiceDslRuntimeModule();
    ServiceDslIdeModule _serviceDslIdeModule = new ServiceDslIdeModule();
    return Guice.createInjector(Modules2.mixin(_serviceDslRuntimeModule, _serviceDslIdeModule));
  }
}