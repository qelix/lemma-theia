/*
 * generated by Xtext 2.12.0
 */
package de.fhdo.lemma.technology.validation

import org.eclipse.xtext.validation.Check
import de.fhdo.lemma.technology.TechnologyPackage
import de.fhdo.lemma.technology.Technology
import de.fhdo.lemma.technology.TechnologySpecificPrimitiveType
import de.fhdo.lemma.data.PrimitiveType
import de.fhdo.lemma.technology.DataFormat
import de.fhdo.lemma.typechecking.TypecheckingUtils
import de.fhdo.lemma.technology.CompatibilityMatrixEntry
import de.fhdo.lemma.technology.CompatibilityDirection
import java.util.List
import de.fhdo.lemma.technology.TechnologyImport
import de.fhdo.lemma.technology.PossiblyImportedTechnologySpecificType
import org.eclipse.xtext.EcoreUtil2
import de.fhdo.lemma.technology.TechnologySpecificProperty
import de.fhdo.lemma.data.PrimitiveValue
import de.fhdo.lemma.technology.OperationTechnology
import de.fhdo.lemma.technology.ServiceAspectPointcutSelector
import de.fhdo.lemma.technology.ServiceAspect
import de.fhdo.lemma.technology.ServiceAspectPointcut
import de.fhdo.lemma.technology.JoinPointType
import de.fhdo.lemma.technology.TechnologyAspect
import de.fhdo.lemma.technology.PropertyFeature
import de.fhdo.lemma.technology.OperationAspectPointcutSelector
import de.fhdo.lemma.technology.OperationAspect
import de.fhdo.lemma.utils.LemmaUtils
import de.fhdo.lemma.data.PrimitiveUnspecified

/**
 * This class contains custom validation rules.
 *
 * @author <a href="mailto:florian.rademacher@fh-dortmund.de">Florian Rademacher</a>
 */
class TechnologyDslValidator extends AbstractTechnologyDslValidator {
    /**
     * Check if technology model contains at least one section
     */
    @Check
    def checkModelNotEmpty(Technology technology) {
        val modelEmpty = technology.primitiveTypes.empty &&
            technology.listTypes.empty &&
            technology.dataStructures.empty &&
            technology.protocols.empty &&
            technology.serviceAspects.empty &&
            technology.deploymentTechnologies.empty &&
            technology.infrastructureTechnologies.empty &&
            technology.operationAspects.empty

        if (modelEmpty)
            error("Model must not be empty", technology,
                TechnologyPackage::Literals.TECHNOLOGY__NAME)
    }

    /**
     * Check that imported file is imported exactly once
     */
    @Check
    def checkImportFileUniqueness(Technology model) {
        val absolutePath = LemmaUtils.absolutePath(model.eResource)
        val absoluteImportPaths = model.imports.map[
            LemmaUtils.convertToAbsolutePath(importURI, absolutePath)
        ]
        val duplicateIndex = LemmaUtils.getDuplicateIndex(absoluteImportPaths, [it])
        if (duplicateIndex === -1) {
            return
        }

        val duplicate = model.imports.get(duplicateIndex)
        error("File is already being imported", duplicate,
            TechnologyPackage::Literals.TECHNOLOGY_IMPORT__IMPORT_URI)
    }

    /**
     * Check if an imported file exists and if it is case sensitive
     */
    @Check
    def checkImportFileExistsAndIsCaseSensitive(TechnologyImport ^import) {
        val importURI = ^import.importURI
        val eResource = ^import.eResource

        if (!LemmaUtils.importFileExists(eResource, importURI))
            error("File not found", ^import,
                TechnologyPackage::Literals.TECHNOLOGY_IMPORT__IMPORT_URI)
        else if (!LemmaUtils.importFileExistsCaseSensitive(eResource, importURI))
            error("Import path and filename must be case sensitive", ^import,
                TechnologyPackage::Literals.TECHNOLOGY_IMPORT__IMPORT_URI)
    }

    /**
     * Check that imported file defines a technology model
     */
    @Check
    def checkImportType(TechnologyImport technologyImport) {
        if (!LemmaUtils.isImportOfType(technologyImport.eResource, technologyImport.importURI,
            Technology))
            error("Import paths are case sensitive, but the case sensitivity of this import path " +
                "does not match its appearance in the filesystem", technologyImport,
                TechnologyPackage::Literals.TECHNOLOGY_IMPORT__IMPORT_URI)
    }

    /**
     * Check that technology does not import itself
     */
    @Check
    def checkSelfImport(TechnologyImport ^import) {
        val thisModelRoot = EcoreUtil2.getContainerOfType(import, Technology)
        val importedModelRoots = LemmaUtils.getImportedModelContents(import.eResource,
            import.importURI)

        // A model imports itself if its root is contained in the roots of the imported model
        if (importedModelRoots.contains(thisModelRoot))
            error("Model must not import itself", import,
                TechnologyPackage::Literals.TECHNOLOGY_IMPORT__IMPORT_URI)
    }

    /**
     * Check that there are not duplicates in the basic built-ins of a technology-specific primitive
     * type
     */
    @Check
    def checkBascBuiltinsUnique(TechnologySpecificPrimitiveType primitiveType) {
        // Note that we use the metamodel interfaces to check for duplicates. That is, because at
        // runtime, only their implementations are available (e.g., instead of PrimitiveBoolean
        // PrimitiveBooleanImpl).
        val basicBuiltins = primitiveType.basicBuiltinPrimitiveTypes.map[class.interfaces.get(0)]
        var PrimitiveType duplicate = null
        var Integer duplicateIndex = null

        // The following construct is just a "classic" search for element duplicates in two lists
        var i = 0
        while (i < basicBuiltins.size - 1 && duplicate === null) {
            val builtin = basicBuiltins.get(i)

            var n = i + 1
            while (n < basicBuiltins.size && duplicate === null) {
                val builtinDuplicateToCheck = basicBuiltins.get(n)

                if (builtinDuplicateToCheck == builtin) {
                    duplicate = primitiveType.basicBuiltinPrimitiveTypes.get(n)
                    duplicateIndex = n
                }

                n++
            }

            i++
        }

        if (duplicate !== null)
            error('''«duplicate.typeName» is already a basic type for «primitiveType.name»''',
                primitiveType, TechnologyPackage::Literals
                    .TECHNOLOGY_SPECIFIC_PRIMITIVE_TYPE__BASIC_BUILTIN_PRIMITIVE_TYPES,
                duplicateIndex
            )
    }

    /**
     * Check that there is only one technology-specific primitive type that is marked as the default
     * for a built-in primitive type. Otherwise, the code generator could not unambiguously decide
     * which technology-specific primitive type to use, when no explicit mapping of a built-in
     * primitive types was specified.
     */
    @Check
    def checkPrimitiveDefaultsUnique(TechnologySpecificPrimitiveType primitiveType) {
        if (!primitiveType.^default) {
            return
        }

        val otherDefaultPrimitiveTypes = primitiveType.technology.primitiveTypes
            .filter[^default && it !== primitiveType]
        val primitiveTypeBuiltins = primitiveType.basicBuiltinPrimitiveTypes
            .map[class.interfaces.get(0)]

        var TechnologySpecificPrimitiveType duplicateContainer = null
        var String duplicateName = null
        var Integer duplicateIndex = null
        var i = 0
        while (i < otherDefaultPrimitiveTypes.size && duplicateContainer === null) {
            val otherDefaultPrimitiveType = otherDefaultPrimitiveTypes.get(i)
            val otherBuiltins = otherDefaultPrimitiveType.basicBuiltinPrimitiveTypes
            var n = 0
            while (n < otherBuiltins.size && duplicateContainer === null) {
                val otherBuiltin = otherBuiltins.get(n).class.interfaces.get(0)
                if (primitiveTypeBuiltins.contains(otherBuiltin)) {
                    duplicateContainer = otherDefaultPrimitiveType
                    duplicateName = otherBuiltins.get(n).typeName
                    duplicateIndex = n
                }
                n++
            }
            i++
        }

        if (duplicateContainer !== null)
            error('''Duplicate default type: «primitiveType.name» is also specified as default ''' +
                '''type for built-in primitive «duplicateName»''',
                duplicateContainer, TechnologyPackage::Literals
                    .TECHNOLOGY_SPECIFIC_PRIMITIVE_TYPE__BASIC_BUILTIN_PRIMITIVE_TYPES,
                duplicateIndex
            )
    }

    /**
     * Check that technology defines at least one default technology-specific primitive type for
     * each built-in primitive type. This ensures, that even if there is no mapping of a built-in
     * primitive type to a technology-specific one, we can deduce a technology-specific type for it
     * when code gets generated.
     */
    @Check
    def checkPrimitiveDefaults(Technology technology) {
        /*
         * Perform the check only if the "types" section is present. However, the presence needs to
         * be checked by relying on the existence of other types, i.e., lists and/or data
         * structures. That is, because the "types" section in the metamodel is not represented by
         * one coherent concept, but each part of the "types" section is directly encapsulated by
         * the root concept Technology. Hence, checking for the existence of the "types" section "as
         * a whole" is not possible.
         */
        val typeSectionIsPresent = !technology.listTypes.empty ||
            !technology.dataStructures.empty ||
            !technology.primitiveTypes.empty

        if (!typeSectionIsPresent) {
            return
        }

        /*
         * Get built-in primitive types of technology-specific primitive types, which are marked as
         * defaults for the basic built-in primitive types. Here, we map them to the metamodel
         * interfaces of the built-in primitive types. That is, because at runtime, instead of,
         * e.g., PrimitiveBoolean (which is a concept from the metamodel and an Ecore interface),
         * its implementing class PrimitiveBooleanImpl will be used.
         */
        val usedDefaultPrimitivesBasics = technology.primitiveTypes
            .filter[^default]
            .map[basicBuiltinPrimitiveTypes]
            .flatten
            .map[class.interfaces.get(0)]
            .toList

        if (usedDefaultPrimitivesBasics.empty) {
            error("Technology must define at least one default primitive type for each built-in " +
                "primitive type", technology, TechnologyPackage::Literals.TECHNOLOGY__NAME)
            return
        }

        /*
         * Get list of all built-in primitive types, i.e., their metamodel interfaces. To be able
         * to retrieve the list from the metamodel, we need an instance of a PrimitiveType to be
         * able to call getBuiltinPrimitiveTypes() as Xcore does not allow static methods.
         */
        val builtinPrimitiveTypes = technology.primitiveTypes
            .findFirst[^default]
            .basicBuiltinPrimitiveTypes
            .get(0)
            .builtinPrimitiveTypes

        /*
         * Throw error if list of default, technology-specific primitive types' basic built-in
         * primitive types does not exhibit all built-in primitive types. That is, there are not
         * defaults defined for each built-in primitive type.
         */
        if (!usedDefaultPrimitivesBasics.containsAll(builtinPrimitiveTypes))
            error("Technology must define at least one default primitive type for each built-in " +
                  "primitive type", technology, TechnologyPackage::Literals.TECHNOLOGY__NAME)
    }

    /**
     * Check that data formats are unique within a _protocol_ (which is the reason why we do not
     * consider data formats in the unique names validator, because we do not want them to be
     * globally unique within the whole technology model)
     */
    @Check
    def checkUniqueDataFormats(DataFormat dataFormat) {
        val allDataFormats = dataFormat.protocol.dataFormats
        var i = 0
        var duplicateFound = false
        var DataFormat currentFormat = null
        do {
            currentFormat = allDataFormats.get(i)
            duplicateFound = currentFormat != dataFormat &&
                currentFormat.formatName == dataFormat.formatName
            i++
        } while (currentFormat != dataFormat && !duplicateFound)

        if(duplicateFound)
            error ('''Duplicate data format «dataFormat.formatName»''', dataFormat,
                TechnologyPackage::Literals.DATA_FORMAT__FORMAT_NAME)
    }

    /**
     * Check if compatibility entries exhibit ambiguous entries or duplicates
     */
    @Check
    def checkCompatibilityMatrix(Technology technology) {
        if (technology.compatibilityEntries.empty) {
            return
        }

        val entrySet = <String> newHashSet
        technology.compatibilityEntries.forEach[entry |
            entry.compatibleTypes.forEach[compatibleType |
                val mappingTypeName = TypecheckingUtils.getTypeName(entry.mappingType.type)
                val compatibleTypeName = TypecheckingUtils.getTypeName(compatibleType.type)
                var ambiguousEntry = false
                var duplicateEntry = false

                /*
                 * The basic idea of the check is to first break down all entries to a consistent
                 * form following the pattern: "type can be converted to other_type". This
                 * corresponds to the semantics of the compatibility direction
                 * MAPPING_TO_COMPATIBLE_TYPES (->). Next, we check if such an entry already exists
                 * in an entry set. We have found an ambiguous entry if this is the case for
                 * BIDIRECTIONAL entries. Otherwise it's a duplicate entry, if the entry could not
                 * be added to the set.
                 */
                switch (entry.direction) {
                    // Match BIDIRECTIONAL entries to both directions, i.e., mapping type -> current
                    // compatible type and current compatible type -> mapping type.
                    case BIDIRECTIONAL:
                        ambiguousEntry = !entrySet.add(mappingTypeName + compatibleTypeName) ||
                            !entrySet.add(compatibleTypeName + mappingTypeName)
                    // COMPATIBLE_TYPES_TO_MAPPING entries become current compatible type ->
                    // mapping type
                    case COMPATIBLE_TYPES_TO_MAPPING:
                        duplicateEntry = !entrySet.add(compatibleTypeName + mappingTypeName)
                    // Default is MAPPING_TO_COMPATIBLE_TYPES: mapping type -> current compatible
                    //                                         type
                    default:
                        duplicateEntry = !entrySet.add(mappingTypeName + compatibleTypeName)
                }

                val errorMessage = if (ambiguousEntry)
                        "Ambiguous entry"
                    else if (duplicateEntry)
                        "Duplicate entry"
                    else
                        null

                if (errorMessage !== null)
                    error(errorMessage, entry,
                        TechnologyPackage::Literals.COMPATIBILITY_MATRIX_ENTRY__TECHNOLOGY)
            ]
        ]
    }

    /**
     * Check that self-compatibility of types is not explicitly described
     */
    @Check
    def checkTypeSelfCompatibility(CompatibilityMatrixEntry entry) {
        if (entry.mappingType === null || entry.compatibleTypes === null) {
            return
        }

        val mappingTypeName = TypecheckingUtils.getTypeName(entry.mappingType.type)
        val compatibleTypeNames = entry.compatibleTypes.map[TypecheckingUtils.getTypeName(it.type)]
        if (compatibleTypeNames.contains(mappingTypeName))
            error("Self-compatibility of types must not be described", entry,
                TechnologyPackage::Literals.COMPATIBILITY_MATRIX_ENTRY__TECHNOLOGY)
    }

    /**
     * For imported types, only the forms "imported compatible types -> local mapping type" or
     * "local compatible types <- imported mapping type" is allowed. That is, the compatibility
     * matrix must declare which imported types may be converted _into_ its types. A bidirectional
     * compatibility direction is prevented, because then all imported technology models must be
     * traversed to decide whether a compatibility entry exists. Furthermore, for an entry with
     * imported types it must always be declared that imported types are convertible into local
     * types. This follows the direction of an initialized parameter of a microservices that has a
     * technology assigned.
     */
    @Check
    def checkImportedTypeCompatibilityDirection(PossiblyImportedTechnologySpecificType type) {
        if (type.import === null) {
            return
        }

        val containingEntry = EcoreUtil2.getContainerOfType(type, CompatibilityMatrixEntry)
        val mappingType = containingEntry.mappingType
        val compatibleTypes = containingEntry.compatibleTypes
        val direction = containingEntry.direction
        val conversionFromImportedToLocal = mappingType == type &&
            direction === CompatibilityDirection.MAPPING_TO_COMPATIBLE_TYPES
            ||
            compatibleTypes.contains(type) &&
            direction === CompatibilityDirection.COMPATIBLE_TYPES_TO_MAPPING

        if (!conversionFromImportedToLocal)
            error("Compatibility entry must describe conversion from imported to local types",
                containingEntry, TechnologyPackage::Literals.COMPATIBILITY_MATRIX_ENTRY__DIRECTION)
    }

    /**
     * Warn, if an entry of the compatibility matrix, that maps two technology-specific primitive
     * types with basic built-in types, overrides built-in type conversion rules
     */
    @Check
    def checkCompatibilityEntryOverridesBuiltinCompatibilityRules(CompatibilityMatrixEntry entry) {
        /* Only accept technology-specific primitive types with basic built-in primitives */
        if (!(entry.mappingType instanceof TechnologySpecificPrimitiveType)) {
            return
        }

        val mappingPrimitiveType = entry.mappingType as TechnologySpecificPrimitiveType
        if (mappingPrimitiveType.basicBuiltinPrimitiveTypes.empty) {
            return
        }

        val compatiblePrimitiveTypes = entry.compatibleTypes.filter[
            it instanceof TechnologySpecificPrimitiveType &&
            !(it as TechnologySpecificPrimitiveType).basicBuiltinPrimitiveTypes.empty
        ].map[it as TechnologySpecificPrimitiveType]
        .toList

        if (compatiblePrimitiveTypes.empty) {
            return
        }

        /*
         * The actual check consists of two steps:
         *     (1) Convert mapping into a canonical form, that enables to consistently call
         *         PrimitiveType.isCompatibleWith(). Therefore, the mapping entry is converted into
         *         a map. Each key corresponds to a primitive basic type, i.e., the "left side" of
         *         isCompatibleWith(). Each entry of the value list corresponds to a primitive type
         *         to check, i.e., the "right side" of compatibleWith(). We need a value list,
         *         because the mapping and compatible primitive types of the entry may exhibit more
         *         more than one basic built-in primitive type. That is, entries like
         *             primitive type DoubleFloat based on double, float default;
         *             primitive type LongInt based on int, long default;
         *             ...
         *             LongInt -> DoubleFloat;
         *         need to be converted (see the rules below) into a map
         *             float: int, long
         *             double: int, long
         *         resulting in the calls
         *             float.isCompatibleWith(int)
         *             float.isCompatibleWith(long)
         *             double.isCompatibleWith(int)
         *             double.isCompatibleWith(long)
         *         which all return true, making the compatibility entry obsolete because the
         *         built-in primitive types are all compatible already.
         *
         *         For this to work, the following rules are applied based on the compatibility
         *         entry's direction to convert a mapping entry into the described canonical
         *         representation within the map:
         *             - MAPPING_TO_COMPATIBLE_TYPES:
         *                  The mapping direction is "compatible type (ct) <- mapping type (mt)",
         *                  i.e., mapping can be converted into compatible type. Then, the canonical
         *                  form is "ct.isCompatibleWith(mt)" with ct=key and mt=value.
         *             - COMPATIBLE_TYPES_TO_MAPPING:
         *                  The mapping direction is "ct -> mt", i.e., compatible can be converted
         *                  into mapping type. Then, the canonical form is "mt.isCompatibleWith(ct)"
         *                  with mt=key and ct=value.
         *             - BIDIRECTIONAL:
         *                  Both entries "ct <- mt" (ct=key, mt=value) and "ct -> mt" (mt=key,
         *                  ct=value) are added to the map.
         *
         *     (2) Iterate over the map and call key.isCompatibleWith(current value from value
         *         list). If this returns true, collect overridden buit-in rules into a message
         *         string.
         *
         *     (3) Display warning that comprises all overridden built-in rules.
         */
        val overriddenDefaultsString = new StringBuilder
        compatiblePrimitiveTypes.forEach[
            // Build canonical representation map
            val compatibilityChecksTodo = buildCanonicalCompatibilityCheckMap(
                mappingPrimitiveType.basicBuiltinPrimitiveTypes, it.basicBuiltinPrimitiveTypes,
                entry.direction
            )

            // Perform actual compatibility checks
            compatibilityChecksTodo.forEach[basicType, typesToCheck | typesToCheck.forEach[
                typeToCheck |
                if (basicType.isCompatibleWith(typeToCheck))
                    overriddenDefaultsString.append(
                        '''«typeToCheck.typeName» to «basicType.typeName», '''
                    )
            ]]
        ]

        // Output message if overridden built-in rules were detected
        val overriddenStringLength = overriddenDefaultsString.length
        if (overriddenStringLength > 0) {
            val message = "Entry corresponds to built-in primitive conversion rules " +
                overriddenDefaultsString.toString.substring(0, overriddenStringLength-2)
            warning(message, entry,
                TechnologyPackage::Literals.COMPATIBILITY_MATRIX_ENTRY__TECHNOLOGY)
        }
    }

    /**
     * Helper method to build a map of a canonical representation for checking of a compatibility
     * matrix entry overrides a built-in type conversion rule
     */
    def buildCanonicalCompatibilityCheckMap(List<PrimitiveType> mappingTypes,
        List<PrimitiveType> compatibleTypes, CompatibilityDirection direction) {
        val canonicalCheckMap = <PrimitiveType, List<PrimitiveType>> newHashMap

        /*
         * From the perspective of the compatibility matrix, the canonical form is "key <- value",
         * i.e., can the value be converted into the key. This corresponds to the call
         * key.isCompatibleWith(value).
         * Therefore, the following rules are applied based on the compatibility entry's direction
         * to convert a mapping entry into the described canonical representation within the map:
         *     - MAPPING_TO_COMPATIBLE_TYPES:
         *         The mapping direction is "compatible type (ct) <- mapping type (mt)",
         *         i.e., mapping can be converted into compatible type. Then, the canonical
         *         form is "ct.isCompatibleWith(mt)" with ct=key and mt=value.
         *     - COMPATIBLE_TYPES_TO_MAPPING:
         *         The mapping direction is "ct -> mt", i.e., compatible can be converted
         *         into mapping type. Then, the canonical form is "mt.isCompatibleWith(ct)"
         *         with mt=key and ct=value.
         *     - BIDIRECTIONAL:
         *         Both entries "ct <- mt" (ct=key, mt=value) and "ct -> mt" (mt=key,
         *         ct=value) are added to the map.
         */
        mappingTypes.forEach[mappingType | compatibleTypes.forEach[compatibleType |
            if (direction === CompatibilityDirection.MAPPING_TO_COMPATIBLE_TYPES) {
                canonicalCheckMap.putIfAbsent(compatibleType, newArrayList)
                canonicalCheckMap.get(compatibleType).add(mappingType)
            } else if (direction === CompatibilityDirection.COMPATIBLE_TYPES_TO_MAPPING) {
                canonicalCheckMap.putIfAbsent(mappingType, newArrayList)
                canonicalCheckMap.get(mappingType).add(compatibleType)
            } else if (direction === CompatibilityDirection.BIDIRECTIONAL) {
                canonicalCheckMap.putIfAbsent(compatibleType, newArrayList)
                canonicalCheckMap.get(compatibleType).add(mappingType)

                canonicalCheckMap.putIfAbsent(mappingType, newArrayList)
                canonicalCheckMap.get(mappingType).add(compatibleType)
            }
        ]]

        return canonicalCheckMap
    }

    /**
     * The unspecified primitive type is forbidden for technology-specific properties
     */
    @Check
    def checkPropertyType(TechnologySpecificProperty property) {
        if (property.type instanceof PrimitiveUnspecified)
            error("Invalid type", property,
                TechnologyPackage::Literals.TECHNOLOGY_SPECIFIC_PROPERTY__TYPE)
    }

    /**
     * Check that the assigned default value of a technology-specific property matches its type
     */
    @Check
    def checkDefaultValueType(PrimitiveValue defaultValue) {
        val property = EcoreUtil2.getContainerOfType(defaultValue, TechnologySpecificProperty)
        if (property !== null && !defaultValue.isOfType(property.type))
            error('''Value is not of type «property.type.typeName» ''', property,
                TechnologyPackage::Literals.TECHNOLOGY_SPECIFIC_PROPERTY__DEFAULT_VALUE)
    }

    /**
     * Check that mandatory technology-specific properties do not specify a default value
     */
    @Check
    def checkMandatoryPropertyNoDefaultValue(TechnologySpecificProperty property) {
        if (property.isMandatory && property.defaultValue !== null)
            error("Mandatory property must not exhibit default value", property,
                TechnologyPackage::Literals.TECHNOLOGY_SPECIFIC_PROPERTY__DEFAULT_VALUE)
    }

    /**
     * Check that features on technology-specific properties are unique
     */
    @Check
    def checkFeatureUniqueness(TechnologySpecificProperty property) {
        val duplicateIndex = LemmaUtils.getDuplicateIndex(property.features, [it])
        if (duplicateIndex > -1)
            error("Duplicate feature", property,
                TechnologyPackage::Literals.TECHNOLOGY_SPECIFIC_PROPERTY__FEATURES, duplicateIndex)
    }

    /**
     * Warn if aspect property exhibits single-valued feature
     */
    @Check
    def warnSingleValuedPropertyOnAspect(TechnologySpecificProperty property) {
        if (property.technologyAspect === null) {
            return
        }

        val singleValuedFeatureIndex = property.features.indexOf(PropertyFeature.SINGLE_VALUED)
        if (singleValuedFeatureIndex > -1)
            warning("Aspect properties are inherently single-valued", property,
                TechnologyPackage::Literals.TECHNOLOGY_SPECIFIC_PROPERTY__FEATURES,
                singleValuedFeatureIndex)
    }

    /**
     * Check uniqueness of operation environments' names in an operation technology
     */
    @Check
    def checkOperationEnvironmentsUniqueNames(OperationTechnology operationTechnology) {
        val operationEnvironments = operationTechnology.operationEnvironments
        val duplicateIndex = LemmaUtils.getDuplicateIndex(operationEnvironments, [environmentName])
        if (duplicateIndex > -1) {
            val duplicateEnvironment = operationEnvironments.get(duplicateIndex)
            error('''Duplicate operation environment «duplicateEnvironment.environmentName»''',
                duplicateEnvironment,
                TechnologyPackage::Literals.OPERATION_ENVIRONMENT__ENVIRONMENT_NAME, duplicateIndex)
        }
    }

    /**
     * Check that there is exactly one default operation environment, if more than on environment
     * is specified for an operation technology
     */
    @Check
    def checkOperationEnvironmentsDefault(OperationTechnology operationTechnology) {
        val operationEnvironments = operationTechnology.operationEnvironments
        /* If there is only one operation environment, treat it implicitly as default */
        if (operationEnvironments.size <= 1)
            return
        /* If there is more than one operation environment, one must be marked as default */
        else if (!operationEnvironments.exists[^default])
            error('''There must be exactly one default environment''',
                operationTechnology, TechnologyPackage::Literals.OPERATION_TECHNOLOGY__NAME)

        /* Check that there is only one default environment */
        val duplicateDefaultIndex = LemmaUtils.getDuplicateIndex(operationEnvironments, [^default],
            [^default === true])
        if (duplicateDefaultIndex > -1) {
            val duplicateEnvironment = operationEnvironments.get(duplicateDefaultIndex)
            error('''There may only be one default environment''',
                duplicateEnvironment, TechnologyPackage::Literals.OPERATION_ENVIRONMENT__DEFAULT,
                duplicateDefaultIndex)
        }
    }

    /**
     * Check uniqueness of service properties' names in an operation technology
     */
    @Check
    def checkServicePropertiesUniqueNames(OperationTechnology operationTechnology) {
        val serviceProperties = operationTechnology.serviceProperties
        val duplicateIndex = LemmaUtils.getDuplicateIndex(serviceProperties, [name])
        if (duplicateIndex > -1) {
            val duplicateProperty = serviceProperties.get(duplicateIndex)
            error('''Duplicate service property «duplicateProperty.name»''',
                duplicateProperty, TechnologyPackage::Literals.TECHNOLOGY_SPECIFIC_PROPERTY__NAME)
        }
    }

    /**
     * Check that per type only one pointcut exists in a service aspect selector
     */
    @Check
    def checkPointcutUniqueness(ServiceAspectPointcutSelector selector) {
        val duplicateIndex = LemmaUtils.getDuplicateIndex(selector.pointcuts, [effectiveType])
        if (duplicateIndex > -1) {
            val duplicatePoincut = selector.pointcuts.get(duplicateIndex)
            error('''Duplicate pointcut «duplicatePoincut.effectiveSelectorName»''',
                TechnologyPackage::Literals.SERVICE_ASPECT_POINTCUT_SELECTOR__POINTCUTS,
                duplicateIndex)
        }
    }

    /**
     * Check that per type only one pointcut exists in an operation aspect selector
     */
    @Check
    def checkPointcutUniqueness(OperationAspectPointcutSelector selector) {
        val duplicateIndex = LemmaUtils.getDuplicateIndex(selector.pointcuts, [effectiveType])
        if (duplicateIndex > -1) {
            val duplicatePoincut = selector.pointcuts.get(duplicateIndex)
            error('''Duplicate pointcut «duplicatePoincut.effectiveSelectorName»''',
                TechnologyPackage::Literals.OPERATION_ASPECT_POINTCUT_SELECTOR__POINTCUTS,
                duplicateIndex)
        }
    }

    /**
     * Check aspect uniqueness considering different types of aspects and join points
     */
    @Check
    def checkAspectUniqueness(Technology technologyModel) {
        for (i : 0..<2) {
            val aspects = switch (i) {
                case 0: technologyModel.serviceAspects
                case 1: technologyModel.operationAspects
            }

            // Collect all aspects in a map that maps aspect names to aspects
            val nameToAspectsMap = <String, List<TechnologyAspect>> newHashMap
            aspects.forEach[
                var aspectsList = nameToAspectsMap.get(name)
                if (aspectsList === null) {
                    aspectsList = <TechnologyAspect> newArrayList
                    nameToAspectsMap.put(name, aspectsList)
                }
                aspectsList.add(it)
            ]

            // Iterate over duplicate aspects, i.e., those aspects for which the map contains a list
            // of aspects with a size greater than 2. Check for duplicate join points leveraging a
            // set.
            nameToAspectsMap.entrySet.filter[value.size > 1].forEach[
                val eponymousAspects = value
                val uniqueJoinPoints = <JoinPointType> newHashSet
                eponymousAspects.forEach[aspect | aspect.joinPoints.forEach[joinPoint |
                    val duplicateJoinPoint = !uniqueJoinPoints.add(joinPoint)
                    if (duplicateJoinPoint)
                        error('''Duplicate aspect «aspect.name» for join point ''' +
                            '''«joinPoint.getName.toLowerCase»''', aspect,
                            TechnologyPackage::Literals.TECHNOLOGY_ASPECT__NAME)
                ]]
            ]
        }
    }

    /**
     * Check that join points of an aspect are unique
     */
    @Check
    def checkJoinPointUniqueness(TechnologyAspect aspect) {
        val duplicateIndex = LemmaUtils.getDuplicateIndex(aspect.joinPoints, [it])
        if (duplicateIndex > -1)
            error("Duplicate join point",
                TechnologyPackage::Literals.TECHNOLOGY_ASPECT__JOIN_POINTS, duplicateIndex)
    }

    /**
     * Check that features on technology aspects are unique
     */
    @Check
    def checkFeatureUniqueness(TechnologyAspect aspect) {
        val duplicateIndex = LemmaUtils.getDuplicateIndex(aspect.features, [it])
        if (duplicateIndex > -1)
            error("Duplicate feature", aspect,
                TechnologyPackage::Literals.TECHNOLOGY_ASPECT__FEATURES, duplicateIndex)
    }

    /**
     * Check that properties of an aspect are unique
     */
    @Check
    def checkPropertyUniqueness(TechnologyAspect aspect) {
        val duplicateIndex = LemmaUtils.getDuplicateIndex(aspect.properties, [name])
        if (duplicateIndex > -1)
            error("Duplicate property",
                TechnologyPackage::Literals.TECHNOLOGY_ASPECT__PROPERTIES, duplicateIndex)
    }

    /**
     * Check that selectors of a service aspect are unique
     */
    @Check
    def checkSelectorUniqueness(ServiceAspect aspect) {
        val duplicateIndex = LemmaUtils.getDuplicateIndex(aspect.pointcutSelectors, [selectorString])
        if (duplicateIndex > -1)
            error("Duplicate selector",
                TechnologyPackage::Literals.SERVICE_ASPECT__POINTCUT_SELECTORS, duplicateIndex)
    }

    /**
     * Check that selectors of an operation aspect are unique
     */
    @Check
    def checkSelectorUniqueness(OperationAspect aspect) {
        val duplicateIndex = LemmaUtils.getDuplicateIndex(aspect.pointcutSelectors, [selectorString])
        if (duplicateIndex > -1)
            error("Duplicate selector",
                TechnologyPackage::Literals.OPERATION_ASPECT__POINTCUT_SELECTORS, duplicateIndex)
    }

    /**
     * Check that pointcut is applicable to at least one join point of the aspect
     */
    @Check
    def checkPointcut(ServiceAspectPointcut pointcut) {
        val aspectJoinPoints = pointcut.selector.serviceAspect.joinPoints
        if (!aspectJoinPoints.exists[pointcut.isValidSelectorFor(it)])
            error('''Pointcut "«pointcut.effectiveSelectorName»" is not applicable to aspect''',
                TechnologyPackage::Literals.SERVICE_ASPECT_POINTCUT__SELECTOR)
    }

    /**
     * Warn for pointcut selectors that do not apply to all join points of a service aspect
     */
    @Check
    def warnNotApplicableAtAllJoinPoints(ServiceAspectPointcutSelector selector) {
        val aspect = selector.serviceAspect
        val notApplicableJoinPoints = aspect.joinPoints.filter[
            !aspect.isValidSelectorForJoinPoint(it, selector)
        ]
        if (notApplicableJoinPoints.empty) {
            return
        }

        val notApplicableString = notApplicableJoinPoints.map[
            switch (it) {
                case JoinPointType.DATA_OPERATIONS: "domainOperations"
                case JoinPointType.DATA_OPERATION_PARAMETERS: "domainParameters"
                case JoinPointType.MICROSERVICES: "microservices"
                case JoinPointType.INTERFACES: "interfaces"
                case JoinPointType.OPERATIONS:"operations"
                case JoinPointType.PARAMETERS: "parameters"
                case JoinPointType.COMPLEX_TYPES: "types"
                case JoinPointType.DATA_FIELDS: "fields"
                default: ""
            }
        ].join(",")
        warning("Selector will not apply to join point" +
            '''«IF notApplicableJoinPoints.size > 1»s«ENDIF» «notApplicableString»''',
            TechnologyPackage::Literals.SERVICE_ASPECT_POINTCUT_SELECTOR__SELECTOR_STRING)
    }
}