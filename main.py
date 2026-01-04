from fastapi import FastAPI
import Search_Engine


app = FastAPI()


@app.get("/")
async def root():
    return {"message": "Welcome to the api docs for macros-finder search engine please go to the /search endpoint to interact with the macro database"}


@app.get("/search/{query}")
def search(query: str):
    """
    Search words or prefix through a prefix tree in server memory.
    Possible word combinations go through a inverted index of food documents.
    Returns search results of food full name and macros associated ordered by weight of importance with sql group by.
    Search must be atleast 2 characters long otherwise you will get no matches found. Query in Search_Engine.py is 
        
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
        LIMIT 10

       
    """
    result = Search_Engine.Proccess_Input(query)  	
    return  { "results": result}
    
