import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const { image_base64, mime_type = "image/jpeg" } = await req.json();

    if (!image_base64 || typeof image_base64 !== "string") {
      return new Response(
        JSON.stringify({ error: "image_base64 is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const apiKey = Deno.env.get("OPENAI_API_KEY");

    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: "OpenAI API key not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const systemPrompt = `You are a high-precision contact extractor for Eventzone.
Your task is to detect and extract contact information from photos of business cards, event badges, visitor passes, name tags, ID cards, company brochures, or professional documents.

GUIDELINES:
1. If the photo shows a business card, badge, pass, or any contact information (even if held in hand, photographed on a table/desk, angled, or surrounded by background elements), set "is_business_card": true.
2. Only set "is_business_card": false if the image has zero professional or contact relevance (e.g., pure landscape, pets, random food, completely blank or unreadable blur).
3. Extract:
   - "name": Full name of the person.
   - "title": Job title, position, or role.
   - "company": Organization, company, startup, or event name.
   - "department": Department or team if mentioned.
   - "email": Primary email address. Fix any OCR spacing (e.g. "name @ domain.com" -> "name@domain.com").
   - "phone": Primary phone number. Include country code (+213, +1, +33, etc.) if visible.
   - "website": Website URL (e.g. "eventzone.dz").
   - "address": Physical address, city, or country.
   - "notes": Any secondary phones, emails, socials (LinkedIn, Twitter/X, Instagram, GitHub), or company tagline.
4. Clean up any obvious OCR formatting issues.
5. If a field is not present on the card, leave it as an empty string (""). Never hallucinate or make up details.`;

    const openAiPayload = {
      model: "gpt-4o-mini",
      temperature: 0.1,
      max_tokens: 500,
      messages: [
        {
          role: "system",
          content: systemPrompt,
        },
        {
          role: "user",
          content: [
            {
              type: "text",
              text: "Scan this business card / badge and extract all contact fields into the required JSON schema.",
            },
            {
              type: "image_url",
              image_url: {
                url: `data:${mime_type};base64,${image_base64}`,
                detail: "auto",
              },
            },
          ],
        },
      ],
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "business_card_extraction",
          strict: true,
          schema: {
            type: "object",
            properties: {
              is_business_card: {
                type: "boolean",
                description:
                  "True if the image represents a business card or professional badge. False if it is an unrelated image.",
              },
              name: {
                type: "string",
                description: "Full personal name on the card.",
              },
              title: {
                type: "string",
                description: "Job title or position.",
              },
              company: {
                type: "string",
                description: "Company or organization name.",
              },
              department: {
                type: "string",
                description: "Department or division.",
              },
              email: {
                type: "string",
                description: "Primary email address.",
              },
              phone: {
                type: "string",
                description: "Primary telephone or mobile number.",
              },
              website: {
                type: "string",
                description: "Company or personal website.",
              },
              address: {
                type: "string",
                description: "Postal address or location.",
              },
              notes: {
                type: "string",
                description: "Social media links, tagline, or additional notes.",
              },
            },
            required: [
              "is_business_card",
              "name",
              "title",
              "company",
              "department",
              "email",
              "phone",
              "website",
              "address",
              "notes",
            ],
            additionalProperties: false,
          },
        },
      },
    };

    const openAiResponse = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(openAiPayload),
    });

    if (!openAiResponse.ok) {
      const errText = await openAiResponse.text();
      console.error("OpenAI API Error:", openAiResponse.status, errText);
      return new Response(
        JSON.stringify({
          error: "OpenAI request failed",
          details: errText,
          status: openAiResponse.status,
        }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const openAiJson = await openAiResponse.json();
    const rawContent = openAiJson.choices?.[0]?.message?.content;

    if (!rawContent) {
      return new Response(
        JSON.stringify({ error: "Empty response from OpenAI" }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const parsedData = JSON.parse(rawContent);

    if (!parsedData.is_business_card) {
      return new Response(
        JSON.stringify({
          success: false,
          is_business_card: false,
          error: "not_a_business_card",
          message: "The scanned image does not appear to be a business card or credential badge.",
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        is_business_card: true,
        data: parsedData,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    console.error("Handler exception:", err);
    return new Response(
      JSON.stringify({ error: err.message || "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
