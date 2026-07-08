import urllib.request
from bs4 import BeautifulSoup
import json

html = urllib.request.urlopen('https://www.maligorus.com').read().decode('utf-8')
soup = BeautifulSoup(html, 'html.parser')

results = []
for a in soup.find_all('a'):
    href = a.get('href', '')
    if 'apple.com' in href or 'play.google.com' in href:
        img = a.find('img')
        img_src = img.get('src') if img else None
        results.append({'url': href, 'image': img_src})

print(json.dumps(results, indent=2))
