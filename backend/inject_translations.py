import os

def main():
    part_path = "crop_translations_part.txt"
    target_path = "../frontend/lib/utils/crop_translator.dart"
    
    with open(part_path, "r", encoding="utf-8") as f:
        part_content = f.read()
        
    with open(target_path, "r", encoding="utf-8") as f:
        target_content = f.read()
        
    # We want to insert part_content right before the `  };\n\n  static String translate` part.
    # So we replace `    },\n  };\n` with `    },\n` + part_content + `  };\n`
    
    insertion_point = "    },\n  };\n"
    if insertion_point in target_content:
        new_content = target_content.replace(insertion_point, "    },\n" + part_content + "  };\n")
        with open(target_path, "w", encoding="utf-8") as f:
            f.write(new_content)
        print("Successfully injected translations!")
    else:
        print("Could not find insertion point.")

if __name__ == "__main__":
    main()
