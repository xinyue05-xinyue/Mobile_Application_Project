from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)


OUTPUT = Path("output/pdf/appendix-d-task-description-donor-services.pdf")
OUTPUT.parent.mkdir(parents=True, exist_ok=True)

styles = getSampleStyleSheet()
body = ParagraphStyle(
    "Body",
    parent=styles["BodyText"],
    fontName="Helvetica",
    fontSize=10.2,
    leading=14.2,
    alignment=TA_JUSTIFY,
    spaceAfter=7,
)
bullet = ParagraphStyle(
    "Bullet",
    parent=body,
    leftIndent=14,
    firstLineIndent=-8,
    spaceAfter=4,
)
question = ParagraphStyle(
    "Question",
    parent=styles["Heading2"],
    fontName="Helvetica-Bold",
    fontSize=11.5,
    leading=15,
    textColor=colors.HexColor("#8E1D2C"),
    spaceBefore=8,
    spaceAfter=7,
)
module = ParagraphStyle(
    "Module",
    parent=styles["Heading3"],
    fontName="Helvetica-Bold",
    fontSize=10.5,
    leading=14,
    spaceBefore=5,
    spaceAfter=4,
)
title = ParagraphStyle(
    "Title",
    parent=styles["Title"],
    fontName="Helvetica-Bold",
    fontSize=15,
    leading=19,
    alignment=TA_CENTER,
    spaceAfter=3,
)
subtitle = ParagraphStyle(
    "Subtitle",
    parent=body,
    fontName="Helvetica-Bold",
    alignment=TA_CENTER,
    spaceAfter=12,
)
small = ParagraphStyle(
    "Small",
    parent=body,
    fontSize=8.7,
    leading=12,
)


def header_footer(canvas, doc):
    canvas.saveState()
    width, height = A4
    canvas.setFont("Helvetica-Bold", 9)
    canvas.drawString(20 * mm, height - 14 * mm, "Appendix D")
    canvas.setStrokeColor(colors.HexColor("#C6283E"))
    canvas.setLineWidth(0.8)
    canvas.line(20 * mm, height - 17 * mm, width - 20 * mm, height - 17 * mm)
    canvas.setFont("Helvetica", 8.5)
    canvas.setFillColor(colors.HexColor("#555555"))
    canvas.drawCentredString(width / 2, 12 * mm, f"Page {doc.page} of 5")
    canvas.restoreState()


doc = BaseDocTemplate(
    str(OUTPUT),
    pagesize=A4,
    rightMargin=20 * mm,
    leftMargin=20 * mm,
    topMargin=23 * mm,
    bottomMargin=20 * mm,
    title="Appendix D - Task Description - Donor Services",
    author="MyDarah project member",
)
frame = Frame(doc.leftMargin, doc.bottomMargin, doc.width, doc.height, id="main")
doc.addPageTemplates([PageTemplate(id="appendix", frames=frame, onPage=header_footer)])

story = []

story.extend(
    [
        Paragraph("Tunku Abdul Rahman University of Management and Technology", title),
        Paragraph("BMIT2073 Mobile Application Development", subtitle),
    ]
)

details = [
    ["Name", ":  ______________________________________________"],
    ["Student ID", ":  ______________________________________________"],
    ["GitHub ID", ":  ______________________________________________"],
    ["Programme", ":  ______________________________________________"],
    ["Group", ":  ______________________________________________"],
]
detail_table = Table(details, colWidths=[30 * mm, 120 * mm])
detail_table.setStyle(
    TableStyle(
        [
            ("FONTNAME", (0, 0), (-1, -1), "Helvetica"),
            ("FONTSIZE", (0, 0), (-1, -1), 10),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ]
    )
)
story.extend([detail_table, Spacer(1, 8 * mm)])
story.append(Paragraph("Task Description", title))
story.append(
    Paragraph(
        "1. Briefly describe the modules/functions you engaged in. Indicate the APIs and external libraries used.",
        question,
    )
)
story.append(
    Paragraph(
        "I was responsible for three related donor-service modules: the Emergency Blood Request Module, the Donation Record and Eligibility Module, and the Rewards and Donor Recognition Module.",
        body,
    )
)

story.append(Paragraph("Emergency Blood Request Module", module))
for text in [
    "Displays active emergency requests that match the signed-in donor's blood type.",
    "Allows a donor to respond to a request and prevents duplicate responses.",
    "Generates a donor-specific emergency attendance QR code containing the request and donor identifiers.",
    "Allows hospital staff to scan the QR code, locate the correct emergency request and response, verify attendance, record the completed donation, and trigger the emergency reward.",
    "Allows hospitals to create requests with a blood type, number of units, urgency, deadline and status, and to review donor responses.",
]:
    story.append(Paragraph(f"- {text}", bullet))

story.append(Paragraph("Donation Record and Eligibility Module", module))
for text in [
    "Stores verified donation records and links them to either a normal donation event or an emergency request.",
    "Shows the donor's donation history, verification status and total number of verified donations.",
    "Updates the donor's next eligible donation date after verification and checks eligibility before event registration.",
    "Keeps attendance verification and reward creation connected to the same donation record to reduce duplicate processing.",
]:
    story.append(Paragraph(f"- {text}", bullet))

story.append(PageBreak())
story.append(Paragraph("1. Modules, APIs and Libraries (continued)", question))
story.append(Paragraph("Rewards and Donor Recognition Module", module))
for text in [
    "Awards points after a verified donation: 100 points for a normal event donation and 150 points for an emergency donation.",
    "Calculates the current point balance from reward transactions and displays reward history.",
    "Provides a reward catalogue, validates the donor's balance and stock, records redemptions, deducts points, and generates a redemption code.",
    "Calculates Bronze (1-5 donations), Silver (6-15 donations) and Gold (16 or more donations) recognition levels and displays progress and benefits.",
]:
    story.append(Paragraph(f"- {text}", bullet))

story.append(Paragraph("APIs and external libraries used", module))
api_data = [
    [Paragraph("Technology", small), Paragraph("Purpose in my modules", small)],
    [
        Paragraph("Supabase Flutter / PostgREST API", small),
        Paragraph(
            "Authentication context and remote CRUD operations for profiles, emergency requests, responses, donations, reward transactions, reward items and redemptions.",
            small,
        ),
    ],
    [
        Paragraph("Supabase PostgreSQL RPC functions", small),
        Paragraph(
            "Server-side event registration, QR verification, emergency-donation verification and reward redemption so related database changes are processed consistently.",
            small,
        ),
    ],
    [
        Paragraph("qr_flutter", small),
        Paragraph("Generates event and emergency donor attendance QR codes.", small),
    ],
    [
        Paragraph("mobile_scanner", small),
        Paragraph("Uses the device camera to scan and decode attendance QR codes.", small),
    ],
    [
        Paragraph("Flutter Material", small),
        Paragraph(
            "Builds responsive forms, cards, dialogs, navigation, validation messages and progress indicators.",
            small,
        ),
    ],
]
api_table = Table(api_data, colWidths=[48 * mm, 112 * mm], repeatRows=1)
api_table.setStyle(
    TableStyle(
        [
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#F7DDE1")),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.HexColor("#5B1722")),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#B99299")),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("LEFTPADDING", (0, 0), (-1, -1), 6),
            ("RIGHTPADDING", (0, 0), (-1, -1), 6),
            ("TOPPADDING", (0, 0), (-1, -1), 6),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
        ]
    )
)
story.append(api_table)

story.append(PageBreak())
story.append(Paragraph("2. Strengths of the modules/functions", question))
for text in [
    "The modules form an end-to-end workflow from an emergency request and donor response to attendance verification, donation recording and reward allocation.",
    "Role-based database policies restrict donor, hospital and organisation operations, while sensitive multi-table operations are handled by PostgreSQL RPC functions.",
    "Event-specific and donor-specific QR payloads allow the scanner to identify the relevant request automatically.",
    "Eligibility and duplicate checks reduce invalid registration, repeated response, repeated verification and duplicated rewards.",
    "The reward transaction ledger provides a traceable history instead of storing only a mutable points total.",
    "The interfaces provide loading, empty, confirmation and error states and follow each role's visual theme.",
]:
    story.append(Paragraph(f"- {text}", bullet))

story.append(PageBreak())
story.append(Paragraph("3. Weaknesses of the modules/functions", question))
for text in [
    "Attendance verification and reward transactions require an internet connection; the current SQLite implementation does not yet queue these writes for later synchronization.",
    "The QR payload contains identifiers but is not cryptographically signed or time-limited, so stronger anti-tampering protection would be required for production use.",
    "Camera quality, lighting and permission settings can affect QR scanning reliability.",
    "The three-month eligibility rule is simplified and does not account for every clinical condition or policy variation.",
    "Reward benefits and partner discounts require agreements, verification procedures and administrative catalogue-management tools before real deployment.",
    "Automated tests cover important rules and QR parsing, but complete integration and device testing could be expanded.",
]:
    story.append(Paragraph(f"- {text}", bullet))

story.append(Paragraph("4. What I learned", question))
for text in [
    "I learned how to structure a Flutter application using screens, models and repository classes instead of placing database logic directly in widgets.",
    "I learned to use asynchronous programming, FutureBuilder, state refresh and mounted checks when communicating with Supabase.",
    "I gained experience with PostgreSQL tables, foreign keys, row-level security policies, storage and RPC functions.",
    "I learned how QR data is generated, parsed and validated and how camera-scanner results can be connected to database workflows.",
    "I learned that attendance, donation and reward updates should be processed atomically to protect data consistency.",
    "I improved my understanding of input validation, error handling, role-based interfaces, test cases and iterative debugging.",
]:
    story.append(Paragraph(f"- {text}", bullet))

story.append(Paragraph("5. Challenges faced", question))
for text in [
    "Coordinating the same workflow across donor, hospital and organisation interfaces while keeping each role's permissions correct.",
    "Ensuring a scanned QR code belongs to the correct donor and request and cannot create a duplicate donation or reward.",
    "Keeping the user interface synchronized with newly saved Supabase data without requiring logout and login.",
    "Designing database functions that update response status, donation history, eligibility and rewards consistently.",
    "Testing time-sensitive event status, deadlines, eligibility dates, camera permissions and different screen sizes.",
]:
    story.append(Paragraph(f"- {text}", bullet))

story.append(PageBreak())
story.append(Paragraph("AI Disclosure Statement", title))
story.append(
    Paragraph(
        "The following statement describes how generative AI supported the assignment. AI suggestions were reviewed, modified and tested before inclusion.",
        body,
    )
)

story.append(Paragraph("1. AI tools used, purposes and included output", question))
story.append(
    Paragraph(
        "<b>ChatGPT</b> was used for brainstorming module boundaries, explaining Flutter and Supabase concepts, improving report wording, and discussing possible causes of implementation problems. Selected explanations and draft wording were rewritten and incorporated into project documentation and this Appendix D.",
        body,
    )
)
story.append(
    Paragraph(
        "<b>OpenAI Codex</b> was used as a coding assistant to inspect the existing Flutter project, trace data flow across screens and repositories, propose and apply focused Dart and SQL changes, diagnose QR/profile/state-refresh issues, and run available formatting, analysis or test checks. Adapted output was included in donor emergency screens, hospital QR verification, donation and reward repositories, Supabase migrations, donor-level displays, and related tests.",
        body,
    )
)

story.append(Paragraph("2. Reasons for selecting the tools and URLs", question))
story.append(
    Paragraph(
        "ChatGPT was selected because it supports interactive explanation and refinement of technical ideas: https://chatgpt.com/. OpenAI Codex was selected because it can inspect a repository, edit multiple related files and assist with verification in the development workspace: https://openai.com/codex/.",
        body,
    )
)

story.append(Paragraph("3. Number of iterations", question))
story.append(
    Paragraph(
        "The work involved approximately 10 ChatGPT prompt-and-review iterations for planning, explanations and writing, and approximately 30 Codex implementation-and-review iterations for coding, debugging, interface refinement and verification. These values are estimates because the tools did not provide a formal assignment-specific iteration counter.",
        body,
    )
)

story.append(Paragraph("4. How the AI output was altered, adopted or extended", question))
story.append(
    Paragraph(
        "I did not accept the generated output without review. I compared suggestions with the existing architecture, selected only relevant changes, adjusted role-specific requirements, field names, colours, validation rules and navigation, and tested the affected workflows. I refined the emergency reward to 150 points, corrected event-specific QR handling, revised donor benefits, and repeatedly reported observed problems so the implementation could be improved. The final design decisions, integration and acceptance of the work remained my responsibility.",
        body,
    )
)

story.extend(
    [
        Spacer(1, 15 * mm),
        Table(
            [
                ["Signature:", "________________________________", "Date:", "________________"],
            ],
            colWidths=[22 * mm, 73 * mm, 15 * mm, 50 * mm],
            style=TableStyle(
                [
                    ("FONTNAME", (0, 0), (-1, -1), "Helvetica"),
                    ("FONTSIZE", (0, 0), (-1, -1), 10),
                    ("VALIGN", (0, 0), (-1, -1), "BOTTOM"),
                ]
            ),
        ),
    ]
)

doc.build(story)
print(OUTPUT.resolve())
