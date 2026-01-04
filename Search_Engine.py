# Setup up Prefix Tree with custom module and data from raw_foods_words.csv 
# Setup Inverted Index with food_dictionary.csv
# Look up macro values on food_macros.csv then display to user
# Create gui so user can input text and receive results
 
import re
import pandas as pd
import Prefix_Tree as trie
import sqlite3

def get_conn():
    return sqlite3.connect('search_engine.db',check_same_thread = False)

# 2. Load tables into DataFrames
conn = get_conn()
keywords_df = pd.read_sql_query("SELECT * FROM keywords_table", conn)



# Create root node

root = trie.TrieNode()

# Use insert method in Prefix Tree on every word inside food words df

for row in keywords_df.itertuples():
    trie.insert(root,row.words.lower())
    
conn.close()
# Take each word from input use prefix tree search functions return macros and title for each food associated

def search(words):
    search_list = []
    
    for word in words:
        
        if trie.search(root,word):
            search_list.append(word)

        prefix_result = trie.prefix(root,word)
        if prefix_result:
            search_list = search_list + prefix_result
    # Use results of search saved in search_list to look up all dictionary entries with word
    # Use all entries to get all fdc ids in list and then search up each id and give macros output
     
    if len(search_list) > 0:
        # Placeholder to prevent sql injection
        placeholders = ', '.join(['?'] * len(search_list))
        # SQLite query that groups concurrent fdc_ids from different words and returns most relevant based on weight
        query = f"""
        SELECT 
            m.description,
            m.protein,
            m.fat,
            m.carbs,
            m.calories,
            SUM(d.weight) as match_score
        FROM food_dict_table as d
        JOIN food_macros_table m ON d.fdc_id = m.fdc_id
        WHERE d.words IN ({placeholders})
        GROUP BY d.fdc_id       
        ORDER BY match_score DESC
        LIMIT 20

        """
        conn = get_conn()
        results_df = pd.read_sql_query(query,conn,params=search_list)   
        result = results_df.to_dict(orient='records')
        conn.close()
        return result
    else:
        result = "No Matches Found."
        return result

 # Strip new line characters and lowercase text output before proccesing
 # Strip new line characters and lowercase text output before proccesing
def Proccess_Input(text):
    try:
         re_pattern = r'\b[a-z0-9]{2,}\b'
         words = re.findall(re_pattern,text)
         return search(words)
            
    except Exception as error:
        return error



