import os
import json
from google import genai
from dotenv import load_dotenv

def main():
    load_dotenv()
    crops = [
        'tomato', 'pepper', 'green bean', 'potato', 'wheat', 'barley', 'corn',
        'sunflower', 'lentil', 'chickpea', 'cotton', 'soybean', 'raspberry',
        'asparagus', 'cucumber', 'apple', 'banana', 'orange', 'lemon', 'grape',
        'strawberry', 'onion', 'garlic', 'carrot', 'cabbage', 'lettuce',
        'spinach', 'eggplant', 'zucchini', 'watermelon', 'melon', 'cherry',
        'peach', 'pear', 'plum', 'olive', 'walnut', 'hazelnut', 'fig',
        'pomegranate', 'apricot', 'sugar beet', 'broccoli', 'cauliflower', 'celery',
        'pea', 'radish', 'artichoke', 'leek', 'kiwi', 'mango', 'avocado', 'pineapple',
        'blueberry', 'blackberry', 'almond', 'pistachio', 'peanut', 'chestnut',
        'sesame', 'tea', 'coffee', 'cocoa', 'rice', 'canola', 'oat'
    ]
    
    langs = ['es', 'it', 'ja', 'ko', 'fr', 'pt', 'hi', 'zh', 'de']
    
    from app.agents.llm_utils import get_genai_client
    client = get_genai_client()
    
    prompt = f"""
    Translate the following list of agricultural crops into the following languages: {', '.join(langs)}.
    Return a JSON object where keys are the language codes (es, it, ja, ko, fr, pt, hi, zh, de) 
    and values are dictionaries mapping the exact English crop name (lowercase) to its capitalized translation in that language.
    
    Crops:
    {', '.join(crops)}
    """
    
    response = client.models.generate_content(
        model='gemini-2.5-flash',
        contents=prompt,
        config=genai.types.GenerateContentConfig(temperature=0.0)
    )
    
    text = response.text.strip()
    if text.startswith("```"):
        text = text.split("\n", 1)[1]
    if text.endswith("```"):
        text = text[:-3]
    if text.startswith("json"):
        text = text[4:]
        
    data = json.loads(text.strip())
    
    # Write to a dart file part
    with open("crop_translations_part.txt", "w", encoding="utf-8") as f:
        for lang, translations in data.items():
            f.write(f"    '{lang}': {{\n")
            for crop in crops:
                val = translations.get(crop, crop).replace("'", "\\'")
                f.write(f"      '{crop}': '{val}',\n")
            f.write(f"    }},\n")
            
    print("Done writing translations part!")

if __name__ == "__main__":
    main()
