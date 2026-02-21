// GenomeParser.swift
// OutliveEngine
//
// On-device parser for 23andMe and AncestryDNA raw genotype files.
// Extracts health-relevant SNPs and maps them to GeneticRisk assessments.
// All processing is synchronous. File data is read but never stored or transmitted.

import Foundation

// MARK: - Parser Errors

enum GenomeParserError: Error, Sendable, LocalizedError {
    case fileReadFailed(underlying: String)
    case unsupportedFormat
    case parsingFailed(line: Int, reason: String)
    case noRelevantSNPs

    var errorDescription: String? {
        switch self {
        case .fileReadFailed(let msg): "Failed to read genome file: \(msg)"
        case .unsupportedFormat:       "Unsupported genome file format. Only 23andMe and AncestryDNA are supported."
        case .parsingFailed(let line, let reason): "Parse error at line \(line): \(reason)"
        case .noRelevantSNPs:          "No relevant SNPs found in the file."
        }
    }
}

// MARK: - File Format

private enum GenomeFileFormat: Sendable {
    case twentyThreeAndMe
    case ancestryDNA
}

// MARK: - Parsed SNP

private struct ParsedSNP: Sendable {
    let rsid: String
    let chromosome: String
    let position: String
    let genotype: String
}

// MARK: - Genome Parser

/// Parses raw genotype files from 23andMe and AncestryDNA, extracting
/// health-relevant SNPs and mapping them to `GeneticRisk` assessments.
///
/// This struct performs all work synchronously on the calling thread.
/// No data is stored beyond the returned `[GeneticRisk]` array, and
/// no network calls are made.
struct GenomeParser: Sendable {

    // MARK: - Target SNPs

    /// The set of SNP rsIDs we extract from raw genotype files.
    private static let targetSNPs: Set<String> = [
        "rs429358",     // APOE (with rs7412)
        "rs7412",       // APOE (with rs429358)
        "rs1801133",    // MTHFR C677T
        "rs762551",     // CYP1A2 caffeine metabolism
        "rs1815739",    // ACTN3 muscle fiber type
        "rs9939609",    // FTO obesity risk
        "rs1544410",    // VDR vitamin D receptor
        "rs4680",       // COMT dopamine metabolism
        "rs12934922",   // BCMO1 beta-carotene conversion
        "rs33972313",   // SLC23A1 vitamin C transport
    ]

    // MARK: - Public API

    /// Parses a raw genotype file and returns an array of genetic risk assessments.
    ///
    /// - Parameter fileURL: The local file URL of the raw genotype data (`.txt` or `.csv`).
    /// - Returns: An array of `GeneticRisk` values for each detected health-relevant SNP.
    /// - Throws: `GenomeParserError` if the file cannot be read, has an unsupported format,
    ///           or contains no relevant SNPs.
    func parse(fileURL: URL) throws -> [GeneticRisk] {
        let contents: String
        do {
            contents = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            throw GenomeParserError.fileReadFailed(underlying: error.localizedDescription)
        }

        let format = try detectFormat(contents: contents)
        let snps = try extractSNPs(contents: contents, format: format)

        guard !snps.isEmpty else {
            throw GenomeParserError.noRelevantSNPs
        }

        return mapToGeneticRisks(snps: snps)
    }

    // MARK: - Format Detection

    /// Detects whether the file is 23andMe or AncestryDNA format by inspecting the header.
    private func detectFormat(contents: String) throws -> GenomeFileFormat {
        let firstLines = contents.prefix(500).lowercased()

        if firstLines.contains("23andme") || firstLines.contains("# rsid\tchromosome\tposition\tgenotype") {
            return .twentyThreeAndMe
        }

        if firstLines.contains("ancestrydna") || firstLines.contains("rsid\tchromosome\tposition\tallele1\tallele2") {
            return .ancestryDNA
        }

        // Try to infer from column count on the first data line.
        let lines = contents.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            let tabFields = trimmed.components(separatedBy: "\t")
            if tabFields.count == 4 && tabFields[0].hasPrefix("rs") {
                return .twentyThreeAndMe
            }
            if tabFields.count >= 5 && tabFields[0].hasPrefix("rs") {
                return .ancestryDNA
            }
            break
        }

        throw GenomeParserError.unsupportedFormat
    }

    // MARK: - SNP Extraction

    /// Extracts target SNPs from the file contents based on the detected format.
    private func extractSNPs(contents: String, format: GenomeFileFormat) throws -> [ParsedSNP] {
        var found: [ParsedSNP] = []
        let lines = contents.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments.
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            let fields = trimmed.components(separatedBy: "\t")

            switch format {
            case .twentyThreeAndMe:
                // Format: rsid  chromosome  position  genotype
                guard fields.count >= 4 else { continue }

                let rsid = fields[0].lowercased()
                guard Self.targetSNPs.contains(rsid) else { continue }

                found.append(ParsedSNP(
                    rsid: rsid,
                    chromosome: fields[1],
                    position: fields[2],
                    genotype: fields[3].uppercased()
                ))

            case .ancestryDNA:
                // Format: rsid  chromosome  position  allele1  allele2
                guard fields.count >= 5 else { continue }

                let rsid = fields[0].lowercased()
                guard Self.targetSNPs.contains(rsid) else { continue }

                let genotype = "\(fields[3].uppercased())\(fields[4].uppercased())"
                found.append(ParsedSNP(
                    rsid: rsid,
                    chromosome: fields[1],
                    position: fields[2],
                    genotype: genotype
                ))
            }
        }

        return found
    }

    // MARK: - Risk Mapping

    /// Maps parsed SNPs to `GeneticRisk` assessments with risk levels and clinical implications.
    private func mapToGeneticRisks(snps: [ParsedSNP]) -> [GeneticRisk] {
        var risks: [GeneticRisk] = []
        let snpDict = Dictionary(snps.map { ($0.rsid, $0) }, uniquingKeysWith: { first, _ in first })

        // --- APOE (requires both rs429358 and rs7412) ---
        if let rs429358 = snpDict["rs429358"], let rs7412 = snpDict["rs7412"] {
            let apoeRisk = mapAPOE(rs429358: rs429358.genotype, rs7412: rs7412.genotype)
            risks.append(apoeRisk)
        }

        // --- MTHFR C677T (rs1801133) ---
        if let snp = snpDict["rs1801133"] {
            risks.append(mapMTHFR(genotype: snp.genotype, rsid: snp.rsid))
        }

        // --- CYP1A2 Caffeine Metabolism (rs762551) ---
        if let snp = snpDict["rs762551"] {
            risks.append(mapCYP1A2(genotype: snp.genotype, rsid: snp.rsid))
        }

        // --- ACTN3 Muscle Fiber Type (rs1815739) ---
        if let snp = snpDict["rs1815739"] {
            risks.append(mapACTN3(genotype: snp.genotype, rsid: snp.rsid))
        }

        // --- FTO Obesity Risk (rs9939609) ---
        if let snp = snpDict["rs9939609"] {
            risks.append(mapFTO(genotype: snp.genotype, rsid: snp.rsid))
        }

        // --- VDR Vitamin D Receptor (rs1544410) ---
        if let snp = snpDict["rs1544410"] {
            risks.append(mapVDR(genotype: snp.genotype, rsid: snp.rsid))
        }

        // --- COMT Dopamine Metabolism (rs4680) ---
        if let snp = snpDict["rs4680"] {
            risks.append(mapCOMT(genotype: snp.genotype, rsid: snp.rsid))
        }

        // --- BCMO1 Beta-Carotene Conversion (rs12934922) ---
        if let snp = snpDict["rs12934922"] {
            risks.append(mapBCMO1(genotype: snp.genotype, rsid: snp.rsid))
        }

        // --- SLC23A1 Vitamin C Transport (rs33972313) ---
        if let snp = snpDict["rs33972313"] {
            risks.append(mapSLC23A1(genotype: snp.genotype, rsid: snp.rsid))
        }

        return risks
    }

    // MARK: - Individual SNP Mappers

    private func mapAPOE(rs429358: String, rs7412: String) -> GeneticRisk {
        // APOE haplotype determination:
        //   e2: rs429358=TT, rs7412=TT
        //   e3: rs429358=TT, rs7412=CC (reference)
        //   e4: rs429358=CC, rs7412=CC
        // Heterozygous combinations yield e3/e4, e2/e3, etc.

        let hasE4 = rs429358.contains("C")   // C allele at rs429358 indicates e4
        let hasE2 = rs7412.contains("T")     // T allele at rs7412 indicates e2

        let isHomozygousE4 = rs429358 == "CC" && rs7412 == "CC"
        let isHeterozygousE4 = hasE4 && !isHomozygousE4

        if isHomozygousE4 {
            return GeneticRisk(
                category: .apoe,
                snpId: "rs429358/rs7412",
                genotype: "e4/e4",
                riskLevel: 1.0,
                implications: [
                    "Significantly elevated Alzheimer's disease risk (10-15x).",
                    "Consider aggressive cardiovascular and neuroprotective protocols.",
                    "Prioritize omega-3 DHA, regular exercise, sleep optimization.",
                    "Discuss with physician — early screening recommended.",
                ]
            )
        } else if isHeterozygousE4 {
            return GeneticRisk(
                category: .apoe,
                snpId: "rs429358/rs7412",
                genotype: hasE2 ? "e2/e4" : "e3/e4",
                riskLevel: 0.6,
                implications: [
                    "Moderately elevated Alzheimer's disease risk (2-3x).",
                    "Neuroprotective lifestyle factors are especially important.",
                    "Optimize sleep, exercise, and omega-3 intake.",
                ]
            )
        } else {
            return GeneticRisk(
                category: .apoe,
                snpId: "rs429358/rs7412",
                genotype: hasE2 ? "e2/e3" : "e3/e3",
                riskLevel: 0.1,
                implications: [
                    "Average or below-average Alzheimer's disease risk.",
                    "Standard neuroprotective recommendations apply.",
                ]
            )
        }
    }

    private func mapMTHFR(genotype: String, rsid: String) -> GeneticRisk {
        switch genotype {
        case "TT":
            return GeneticRisk(
                category: .mthfr,
                snpId: rsid,
                genotype: genotype,
                riskLevel: 0.8,
                implications: [
                    "Homozygous MTHFR C677T — ~70% reduction in enzyme activity.",
                    "Use methylfolate (5-MTHF) instead of folic acid.",
                    "Monitor homocysteine levels regularly.",
                    "Consider methylated B-complex supplementation.",
                ]
            )
        case "CT", "TC":
            return GeneticRisk(
                category: .mthfr,
                snpId: rsid,
                genotype: genotype,
                riskLevel: 0.4,
                implications: [
                    "Heterozygous MTHFR C677T — ~35% reduction in enzyme activity.",
                    "Methylfolate preferred over folic acid.",
                    "Periodic homocysteine testing recommended.",
                ]
            )
        default: // CC (wild-type)
            return GeneticRisk(
                category: .mthfr,
                snpId: rsid,
                genotype: genotype,
                riskLevel: 0.05,
                implications: [
                    "Normal MTHFR enzyme activity.",
                    "Standard folate intake is sufficient.",
                ]
            )
        }
    }

    private func mapCYP1A2(genotype: String, rsid: String) -> GeneticRisk {
        switch genotype {
        case "AA":
            return GeneticRisk(
                category: .cyp1a2,
                snpId: rsid,
                genotype: genotype,
                riskLevel: 0.1,
                implications: [
                    "Fast caffeine metabolizer.",
                    "Moderate coffee consumption may be cardioprotective.",
                    "Caffeine can be used strategically for performance.",
                ]
            )
        case "AC", "CA":
            return GeneticRisk(
                category: .cyp1a2,
                snpId: rsid,
                genotype: genotype,
                riskLevel: 0.4,
                implications: [
                    "Intermediate caffeine metabolizer.",
                    "Limit caffeine to 200-300mg/day.",
                    "Avoid caffeine after early afternoon for sleep quality.",
                ]
            )
        default: // CC
            return GeneticRisk(
                category: .cyp1a2,
                snpId: rsid,
                genotype: genotype,
                riskLevel: 0.7,
                implications: [
                    "Slow caffeine metabolizer.",
                    "Caffeine increases cardiovascular risk.",
                    "Keep intake below 200mg/day; none after noon.",
                ]
            )
        }
    }

    private func mapACTN3(genotype: String, rsid: String) -> GeneticRisk {
        switch genotype {
        case "CC":
            return GeneticRisk(
                category: .actn3,
                snpId: rsid,
                genotype: genotype,
                riskLevel: 0.1,
                implications: [
                    "Full alpha-actinin-3 expression — fast-twitch muscle advantage.",
                    "Favors power/sprint training adaptations.",
                    "May benefit from higher-intensity, lower-volume protocols.",
                ]
            )
        case "CT", "TC":
            return GeneticRisk(
                category: .actn3,
                snpId: rsid,
                genotype: genotype,
                riskLevel: 0.3,
                implications: [
                    "Partial alpha-actinin-3 expression.",
                    "Balanced response to both power and endurance training.",
                ]
            )
        default: // TT
            return GeneticRisk(
                category: .actn3,
                snpId: rsid,
                genotype: genotype,
                riskLevel: 0.5,
                implications: [
                    "No alpha-actinin-3 production — endurance fiber advantage.",
                    "May respond better to higher-volume, endurance-oriented training.",
                    "Potentially slower recovery from explosive efforts.",
                ]
            )
        }
    }

    private func mapFTO(genotype: String, rsid: String) -> GeneticRisk {
        switch genotype {
        case "AA":
            return GeneticRisk(
                category: .fto,
                snpId: rsid,
                genotype: genotype,
                riskLevel: 0.8,
                implications: [
                    "Homozygous FTO risk allele — elevated obesity risk.",
                    "Higher baseline appetite and reduced satiety signaling.",
                    "Structured meal timing and protein-forward meals recommended.",
                    "Exercise provides outsized benefit for weight management.",
                ]
            )
        case "AT", "TA":
            return GeneticRisk(
                category: .fto,
                snpId: rsid,
                genotype: genotype,
                riskLevel: 0.4,
                implications: [
                    "Heterozygous FTO — moderately elevated obesity risk.",
                    "Mindful eating and regular exercise are important.",
                ]
            )
        default: // TT
            return GeneticRisk(
                category: .fto,
                snpId: rsid,
                genotype: genotype,
                riskLevel: 0.1,
                implications: [
                    "No elevated FTO-related obesity risk.",
                    "Standard nutritional guidelines apply.",
                ]
            )
        }
    }

    private func mapVDR(genotype: String, rsid: String) -> GeneticRisk {
        switch genotype {
        case "AA":
            return GeneticRisk(
                category: .vdr,
                snpId: rsid,
                genotype: genotype,
                riskLevel: 0.6,
                implications: [
                    "Reduced vitamin D receptor efficiency.",
                    "Higher vitamin D supplementation may be needed (5000-10000 IU/day).",
                    "Monitor 25(OH)D levels — target 60-80 ng/mL.",
                ]
            )
        case "AG", "GA":
            return GeneticRisk(
                category: .vdr,
                snpId: rsid,
                genotype: genotype,
                riskLevel: 0.3,
                implications: [
                    "Partially reduced VDR efficiency.",
                    "Moderate vitamin D supplementation recommended (2000-5000 IU/day).",
                ]
            )
        default: // GG
            return GeneticRisk(
                category: .vdr,
                snpId: rsid,
                genotype: genotype,
                riskLevel: 0.1,
                implications: [
                    "Normal vitamin D receptor function.",
                    "Standard vitamin D intake is typically sufficient.",
                ]
            )
        }
    }

    private func mapCOMT(genotype: String, rsid: String) -> GeneticRisk {
        switch genotype {
        case "AA":
            return GeneticRisk(
                category: .comt,
                snpId: rsid,
                genotype: genotype,
                riskLevel: 0.5,
                implications: [
                    "COMT Met/Met — slow dopamine clearance (Worrier phenotype).",
                    "Higher baseline dopamine — better focus, but more stress-sensitive.",
                    "May benefit from stress management, magnesium, adaptogenic herbs.",
                    "Avoid excess catechol-containing supplements (e.g., high-dose green tea).",
                ]
            )
        case "AG", "GA":
            return GeneticRisk(
                category: .comt,
                snpId: rsid,
                genotype: genotype,
                riskLevel: 0.25,
                implications: [
                    "COMT Val/Met — intermediate dopamine clearance.",
                    "Balanced stress response and cognitive flexibility.",
                ]
            )
        default: // GG
            return GeneticRisk(
                category: .comt,
                snpId: rsid,
                genotype: genotype,
                riskLevel: 0.2,
                implications: [
                    "COMT Val/Val — fast dopamine clearance (Warrior phenotype).",
                    "More resilient under stress, but may have lower baseline focus.",
                    "May benefit from dopamine-supporting nutrients (tyrosine, B6).",
                ]
            )
        }
    }

    private func mapBCMO1(genotype: String, rsid: String) -> GeneticRisk {
        switch genotype {
        case "TT":
            return GeneticRisk(
                category: .bcmo1,
                snpId: rsid,
                genotype: genotype,
                riskLevel: 0.7,
                implications: [
                    "Significantly reduced beta-carotene to vitamin A conversion (~70% reduction).",
                    "Consider preformed vitamin A (retinol) from animal sources or supplements.",
                    "Plant-based beta-carotene is a poor vitamin A source for this genotype.",
                ]
            )
        case "AT", "TA":
            return GeneticRisk(
                category: .bcmo1,
                snpId: rsid,
                genotype: genotype,
                riskLevel: 0.35,
                implications: [
                    "Moderately reduced beta-carotene conversion (~35% reduction).",
                    "Include some preformed vitamin A alongside carotenoid-rich foods.",
                ]
            )
        default: // AA
            return GeneticRisk(
                category: .bcmo1,
                snpId: rsid,
                genotype: genotype,
                riskLevel: 0.05,
                implications: [
                    "Normal beta-carotene to vitamin A conversion.",
                    "Plant-based carotenoids are an effective vitamin A source.",
                ]
            )
        }
    }

    private func mapSLC23A1(genotype: String, rsid: String) -> GeneticRisk {
        switch genotype {
        case "AA":
            return GeneticRisk(
                category: .slc23a1,
                snpId: rsid,
                genotype: genotype,
                riskLevel: 0.6,
                implications: [
                    "Reduced vitamin C transporter activity.",
                    "Higher vitamin C intake may be needed to maintain optimal plasma levels.",
                    "Consider 500-1000mg supplementation in divided doses.",
                ]
            )
        case "AG", "GA":
            return GeneticRisk(
                category: .slc23a1,
                snpId: rsid,
                genotype: genotype,
                riskLevel: 0.3,
                implications: [
                    "Partially reduced vitamin C transport.",
                    "Ensure adequate dietary vitamin C from citrus, peppers, and berries.",
                ]
            )
        default: // GG
            return GeneticRisk(
                category: .slc23a1,
                snpId: rsid,
                genotype: genotype,
                riskLevel: 0.05,
                implications: [
                    "Normal vitamin C transport and absorption.",
                    "Standard dietary intake is typically sufficient.",
                ]
            )
        }
    }
}
