from pathlib import Path
from zipfile import ZipFile
from copy import deepcopy
from lxml import etree as E
import hashlib

ref=Path(r'C:\Users\QIUQIN_\.codex\plugins\cache\openai-curated-remote\openai-templates\0.1.1\skills\artifact-template-system-design\assets\reference.docx')
out=Path('BMIT3273_Set_1_Questions.docx')
ns={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
w='{'+ns['w']+'}'
with ZipFile(ref) as z:
    root=E.fromstring(z.read('word/document.xml'))
    body=root.find('w:body',ns)
    ps=body.findall('w:p',ns)
    patterns={ 'title':deepcopy(ps[8]), 'heading':deepcopy(ps[21]), 'body':deepcopy(ps[22]) }
    sect=deepcopy(body.find('w:sectPr',ns))
    for el in list(body): body.remove(el)
    def add(text,kind='body'):
        p=deepcopy(patterns[kind])
        props=p.find('w:pPr',ns)
        for ch in list(p):
            if ch is not props: p.remove(ch)
        r=E.SubElement(p,w+'r'); t=E.SubElement(r,w+'t'); t.text=text
        body.append(p)
    add('BMIT3273 Cloud Computing','title')
    add('Practical Test Set 1','title')
    add('Question requirements and marking guide')
    add('Complete four AWS tasks worth 25 marks each, for a total of 100 marks. The following checklist covers the requirements checked by the Set 1 auto-grader.')
    add('Replace <name> with your student name in lowercase with spaces removed. The script uses the AWS session’s configured region. Lambda requires the exact function name; the other resource searches accept names containing the specified pattern.')
    sections=[
      ('Question 1 EC2 with Launch Template',[
       '5 marks — Launch template named lt-<name>.',
       '3 marks — Template instance type is t3.micro.',
       '2 marks — Template IAM instance profile is LabInstanceProfile.',
       '5 marks — Template User Data installs a web server such as httpd, Apache or nginx.',
       '5 marks — A running EC2 instance named ec2-<name>.',
       '5 marks — Its public HTTP webpage displays your name and student ID.']),
      ('Question 2 S3 Static Website',[
       '3 marks — Bucket named s3-<name>.',
       '5 marks — Static website hosting is enabled.',
       '3 marks — index.html is uploaded.',
       '2 marks — error.html is uploaded.',
       '5 marks — Bucket policy allows public read through s3:GetObject.',
       '7 marks — The website is accessible and displays your student name.']),
      ('Question 3 Lambda Function',[
       '5 marks — Function named exactly lambda-<name>.',
       '3 marks — Python 3 runtime.',
       '3 marks — Execution role is LabRole.',
       '3 marks — Environment variable STUDENT_NAME exists.',
       '3 marks — Environment variable STUDENT_ID exists.',
       '3 marks — Function invocation succeeds.',
       '5 marks — The response contains your name and student ID.']),
      ('Question 4 DynamoDB Table',[
       '5 marks — Table named ddb-<name>.',
       '5 marks — Partition key is student_id.',
       '5 marks — Sort key is course_code.',
       '5 marks — A student record exists with your student ID and course_code BMIT3273.',
       '5 marks — That record has status set to active.'])]
    for title,lines in sections:
        add(title,'heading')
        add('Total 25 marks')
        for line in lines: add(line)
    add('Expected DynamoDB record','heading')
    add('Use String types for student_id, course_code and status. The grader tries the student ID in uppercase, then lowercase. Use the exact lowercase attribute names shown below.')
    add('{ "student_id": "YOUR_STUDENT_ID", "course_code": "BMIT3273", "status": "active" }')
    add('Example final output','heading')
    add('Illustrative output when all checks pass. This is not an actual AWS grading result.')
    for line in ['FINAL RESULT','Question 1: EC2 + LT     ########## 25/25','Question 2: S3 Website   ########## 25/25','Question 3: Lambda       ########## 25/25','Question 4: DynamoDB     ########## 25/25','TOTAL SCORE : 100 / 100','* PERFECT SCORE - Excellent work! *','Mr Low blessing you!']: add(line)
    add('Running the grader','heading')
    add('Run the original Python script in your configured AWS lab environment and enter your student name and ID. It checks resources and HTTP webpages and invokes your Lambda function. Some checks award partial marks when only part of a requirement is met.')
    body.append(sect)
    with ZipFile(out,'w') as dst:
        for entry in z.infolist():
            dst.writestr(deepcopy(entry),E.tostring(root,xml_declaration=True,encoding='UTF-8',standalone=True) if entry.filename=='word/document.xml' else z.read(entry.filename))
    with ZipFile(out) as final:
        assert all(final.read(n)==z.read(n) for n in z.namelist() if n!='word/document.xml')
Path('.docx-set1/artifact.md').write_text('Reference: '+str(ref)+'\nSHA256: '+hashlib.sha256(ref.read_bytes()).hexdigest()+'\nCloned Title, Heading 1 and normal paragraphs for questions and marking lines. Retained final section geometry and every package part except document.xml byte for byte. Optional architecture tables and proposal placeholders removed. Visual verification unavailable: packaged renderer cannot find soffice.exe.\n',encoding='utf-8')
print(out.resolve())

