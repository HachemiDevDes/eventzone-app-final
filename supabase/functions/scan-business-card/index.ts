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

    const systemPrompt = `You are a dedicated, high-precision OCR and contact extractor for Eventzone business cards and event badges.
Your sole purpose is to extract contact information from business cards, name badges, event badges, and corporate identification cards.

CRITICAL INSTRUCTIONS:
1. RESTRICTION: You MUST ONLY process business cards, name badges, conference badges, and professional identity cards.
2. If the image is NOT a business card or credential badge (for example: random scenery, animals, food, invoices, handwritten memos, cars), you MUST set "is_business_card": false, and leave all contact fields as empty strings.
3. If it IS a business card or badge, set "is_business_card": true and carefully extract:
   - "name": Full name of the individual.
   - "title": Job title, role, or profession (e.g. CEO, Marketing Director, Lead Developer).
   - "company": Organization, company, or brand name.
   - "department": Department or unit, if stated.
   - "email": Primary email address. Clean up any OCR artifacts.
   - "phone": Primary phone/mobile number. Preserve the country code (+213, +1, +33, etc.) if visible.
   - "website": Website URL.
   - "address": Physical address or city/country.
   - "notes": Any secondary phones, emails, social handles (e.g. LinkedIn, Twitter/X), or business slogans/services.
4. Correct typical visual OCR confusions (e.g. '0' vs 'O', '1' vs 'l' in emails/phones, '@' symbol spacing).
5. Never invent or hallucinate information that is not visible on the card.`;

    const openAiPayload = {
      model: "gpt-4o-mini",
      temperature: 0.1,
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
                detail: "high",
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
