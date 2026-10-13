/* =====================================================================
   QUESTION BANK — this is the only file you need to edit.
   ---------------------------------------------------------------------
   Each question looks like this:
   {
     q: "The question text?",
     options: ["Answer A", "Answer B", "Answer C", "Answer D"],  // exactly 4
     answer: 0,          // index of the correct option: 0=A, 1=B, 2=C, 3=D
     explain: "Shown after answering — the training point.",     // optional
     ref: "Where to read more, e.g. SDS Section 8",               // optional
     draft: true         // optional — draft questions are NOT played yet
   }
   Answer options are shuffled automatically every game.
   Category icons: flame, extinguisher, sprinkler, hazard, helmet,
   shieldFlame, shieldCheck, hydrant, bell (or any emoji).
   The more questions per category, the less repetition between rounds.
   ===================================================================== */

window.GAME_SETTINGS = {
  title: "Brigit Trivia League",
  subtitle: "Train your brain. Beat your PB. Top the leaderboard.",
  secondsPerQuestion: 20,   // time per question
  questionsPerRound: 10,    // questions in one round
  basePoints: 100,          // points for a correct answer
  maxSpeedBonus: 100        // sprint bonus for answering fast (scales with time left)
};

/* Sectors — players pick theirs, and sectors compete on their own league table. */
window.SECTORS = [
  "Technical Johannesburg",
  "Exports",
  "Passive Fire Containment",
  "Special Risk",
  "Sprinklers & Valves",
  "Fire Detection",
  "Gas Suppression",
  "Portable Extinguishers"
];

window.QUIZ_CATEGORIES = [
  /* ------------------------------------------------------------------ */
  {
    id: "fire",
    name: "Fire Standards",
    icon: "flame",
    description: "Fire classes, extinguishers and standards",
    questions: [
      {
        q: "What three elements make up the fire triangle?",
        options: ["Heat, fuel and oxygen", "Heat, smoke and fuel", "Oxygen, water and heat", "Fuel, sparks and smoke"],
        answer: 0,
        explain: "Remove any one of heat, fuel or oxygen and the fire goes out."
      },
      {
        q: "A Class A fire involves which type of material?",
        options: ["Ordinary solids like wood, paper and textiles", "Flammable liquids", "Live electrical equipment", "Cooking oils and fats"],
        answer: 0
      },
      {
        q: "Petrol, diesel and paint thinners burning are which class of fire?",
        options: ["Class B", "Class A", "Class D", "Class F"],
        answer: 0,
        explain: "Class B = flammable liquids."
      },
      {
        q: "What does the PASS technique for using an extinguisher stand for?",
        options: ["Pull, Aim, Squeeze, Sweep", "Point, Activate, Spray, Stop", "Pull, Activate, Spray, Sweep", "Press, Aim, Squeeze, Stand"],
        answer: 0,
        explain: "Aim at the base of the fire, not at the flames."
      },
      {
        q: "Which extinguisher is the best choice for a fire in a live electrical panel?",
        options: ["CO₂ (carbon dioxide)", "Water", "Foam", "Wet chemical"],
        answer: 0,
        explain: "CO₂ does not conduct electricity and leaves no residue on equipment."
      },
      {
        q: "Why should you never use water on a burning pan of cooking oil?",
        options: ["It causes a violent flare-up that spreads burning oil", "Water makes the smoke toxic", "It cools the oil too slowly", "It's fine — water always works"],
        answer: 0,
        explain: "Use a wet chemical extinguisher or a fire blanket on cooking-oil (Class F) fires."
      },
      {
        q: "Which part of the South African National Building Regulations covers fire protection?",
        options: ["SANS 10400-T", "SANS 10400-A", "SANS 10142-1", "SANS 10400-XA"],
        answer: 0,
        explain: "SANS 10400-T deals with fire protection in buildings. (10142-1 is electrical wiring; XA is energy usage.)"
      },
      {
        q: "How often must portable fire extinguishers be serviced in South Africa?",
        options: ["At least once a year", "Every 5 years", "Only after use", "Every month"],
        answer: 0,
        explain: "Annual servicing by a registered technician, per SANS 1475. Visual checks should be done more often.",
        ref: "SANS 1475-1"
      }
    ]
  },

  /* ------------------------------------------------------------------ */
  {
    id: "policies",
    name: "Company Policies",
    required: true,            // everyone must finish this race at least once
    icon: "shieldFlame",
    description: "Who we are and how we work",
    questions: [
      // TEMPLATES — replace with your own company questions, then delete `draft: true`
      {
        draft: true,
        q: "In which year was our company founded?",
        options: ["____", "____", "____", "____"],
        answer: 0,
        explain: "Add a short fact about the company's history here."
      },
      {
        draft: true,
        q: "Who must you report to first if you are injured on site?",
        options: ["Your supervisor", "____", "____", "____"],
        answer: 0,
        explain: "Name the person/role from your company procedure."
      }
    ]
  },

  /* ------------------------------------------------------------------ */
  {
    id: "datasheets",
    name: "Datasheets",
    icon: "sprinkler",
    description: "Product specs and technical data",
    questions: [
      // Product questions will come from Base44. Template:
      {
        draft: true,
        q: "What is the rated operating pressure of product ____?",
        options: ["____", "____", "____", "____"],
        answer: 0,
        ref: "Product datasheet ____"
      }
    ]
  },

  /* ------------------------------------------------------------------ */
  {
    id: "sds",
    name: "Safety Data Sheets",
    icon: "hazard",
    description: "Reading and using SDS documents",
    questions: [
      {
        q: "How many sections does a GHS-format Safety Data Sheet have?",
        options: ["16", "8", "12", "20"],
        answer: 0
      },
      {
        q: "Which SDS section tells you what PPE to wear?",
        options: ["Section 8 – Exposure controls / personal protection", "Section 2 – Hazard identification", "Section 11 – Toxicological information", "Section 14 – Transport information"],
        answer: 0,
        ref: "SDS Section 8"
      },
      {
        q: "Someone splashes a chemical in their eyes. Which SDS section do you check first?",
        options: ["Section 4 – First-aid measures", "Section 6 – Accidental release", "Section 9 – Physical properties", "Section 15 – Regulatory information"],
        answer: 0,
        ref: "SDS Section 4"
      },
      {
        q: "Where on the SDS will you find what to do if the product spills?",
        options: ["Section 6 – Accidental release measures", "Section 5 – Fire-fighting measures", "Section 7 – Handling and storage", "Section 13 – Disposal considerations"],
        answer: 0,
        ref: "SDS Section 6"
      },
      {
        q: "Which section lists the right extinguishing media if the product catches fire?",
        options: ["Section 5 – Fire-fighting measures", "Section 3 – Composition", "Section 8 – Exposure controls", "Section 10 – Stability and reactivity"],
        answer: 0,
        ref: "SDS Section 5"
      },
      {
        q: "On a GHS label, which signal word indicates the MORE severe hazard?",
        options: ["Danger", "Warning", "Caution", "Notice"],
        answer: 0,
        explain: "GHS uses only two signal words: 'Danger' (more severe) and 'Warning' (less severe)."
      },
      {
        q: "A GHS pictogram showing a skull and crossbones means…",
        options: ["Acute toxicity — can be fatal or toxic", "Flammable", "Corrosive", "Harmful to the environment"],
        answer: 0
      },
      {
        q: "Where would you find the flash point of a product?",
        options: ["Section 9 – Physical and chemical properties", "Section 2 – Hazard identification", "Section 12 – Ecological information", "Section 16 – Other information"],
        answer: 0,
        ref: "SDS Section 9"
      }
    ]
  },

  /* ------------------------------------------------------------------ */
  {
    id: "ops",
    name: "Operational Manuals",
    icon: "helmet",
    description: "Safe work procedures on the job",
    questions: [
      {
        q: "In the hierarchy of controls, which is the MOST effective way to manage a hazard?",
        options: ["Eliminate the hazard", "Wear PPE", "Put up warning signs", "Train the workers"],
        answer: 0,
        explain: "Elimination → Substitution → Engineering → Administrative → PPE. PPE is the last line of defence."
      },
      {
        q: "What is the purpose of lockout/tagout (LOTO)?",
        options: ["To make sure equipment can't be started while it's being worked on", "To lock the tool store at night", "To tag broken tools for disposal", "To record who used a machine last"],
        answer: 0
      },
      {
        q: "A near miss is…",
        options: ["An event that could have caused injury or damage but didn't", "A minor injury needing first aid", "A missed deadline", "An accident that caused damage only"],
        answer: 0,
        explain: "Report near misses — they show where the next real incident will come from."
      },
      {
        q: "Which South African Act is the main law covering health and safety at work?",
        options: ["Occupational Health and Safety Act 85 of 1993", "Labour Relations Act 66 of 1995", "Basic Conditions of Employment Act 75 of 1997", "Mine Health and Safety Act 29 of 1996"],
        answer: 0,
        explain: "The MHSA applies to mines; most other workplaces fall under the OHS Act."
      },
      {
        q: "You notice a damaged guard on a machine. What should you do?",
        options: ["Stop using it and report it immediately", "Keep working carefully", "Fix it yourself with tape", "Mention it at the next monthly meeting"],
        answer: 0
      },
      {
        q: "When is the best time to check your PPE for damage?",
        options: ["Before every use", "Once a month", "Only when it looks dirty", "When your supervisor asks"],
        answer: 0
      },
      {
        q: "An emergency exit is blocked by pallets. This is…",
        options: ["An unsafe condition that must be cleared and reported", "Acceptable if it's temporary", "Only a problem during a drill", "The forklift driver's problem only"],
        answer: 0
      },
      {
        q: "When the evacuation alarm sounds, you should…",
        options: ["Stop work, leave by the nearest safe exit and go to the assembly point", "Finish your task first", "Collect your belongings, then leave", "Wait to see if it's a false alarm"],
        answer: 0
      }
    ]
  },

  /* ------------------------------------------------------------------ */
  {
    id: "certification",
    name: "Product Certification",
    icon: "shieldCheck",
    description: "Approvals and certification on our products",
    comingSoon: true,
    questions: []
  }
];
