export type Locale = "fr" | "en";
export type I18nText = Partial<Record<Locale, string>>;

export type Role = "owner" | "admin" | "pastor" | "editor" | "member";
export type MembershipStatus = "pending" | "active" | "suspended" | "left";
export const STAFF_ROLES: Role[] = ["owner", "admin", "pastor", "editor"];
export const ADMIN_ROLES: Role[] = ["owner", "admin"];

export interface Church {
  id: string;
  slug: string;
  name: string;
  city: string | null;
  country: string | null;
  timezone: string;
  default_locale: Locale;
  join_mode: "open" | "approval" | "invite";
  status: "pending" | "active" | "suspended";
  church_type: string | null;
  review_note: string | null;
  submitted_for_review_at: string | null;
}

export interface Branding {
  church_id: string;
  logo_url: string | null;
  cover_url: string | null;
  primary_color: string;
  accent_color: string;
  tagline: I18nText | null;
  welcome_text: I18nText | null;
  about_text: I18nText | null;
  featured_video_url: string | null;
  address: string | null;
  phone: string | null;
  email: string | null;
  website: string | null;
  socials: Record<string, string>;
}

export interface StaffMembership {
  id: string;
  church_id: string;
  role: Role;
  status: MembershipStatus;
  churches: Church | null;
}

export interface Member {
  id: string;
  user_id: string;
  role: Role;
  status: MembershipStatus;
  joined_at: string | null;
  created_at: string;
}

export interface Profile {
  id: string;
  email: string | null;
  first_name: string | null;
  last_name: string | null;
  phone: string | null;
}

export interface EventCategory {
  id: string;
  church_id: string;
  name: I18nText;
  sort: number;
}

export interface ChurchEvent {
  id: string;
  church_id: string;
  category_id: string | null;
  title: I18nText;
  description: I18nText | null;
  poster_url: string | null;
  starts_at: string;
  ends_at: string | null;
  location: string | null;
  capacity: number | null;
  max_seats_per_registration: number;
  registration_open: boolean;
  visibility: "public" | "members";
  published_at: string | null;
}

export interface Registration {
  id: string;
  event_id: string;
  user_id: string;
  status: "confirmed" | "waitlist" | "cancelled";
  seats: number;
  answers: Record<string, unknown>;
  qr_token: string;
  checked_in_at: string | null;
  created_at: string;
}

export interface Announcement {
  id: string;
  church_id: string;
  title: I18nText;
  body: I18nText;
  audience: "all" | "members";
  publish_at: string;
  push_sent_at: string | null;
  created_at: string;
}

export interface Invite {
  id: string;
  code: string;
  role: Role;
  max_uses: number | null;
  uses: number;
  expires_at: string | null;
  created_at: string;
}

export type FeedbackKind = "bug" | "idea" | "other";
export type FeedbackStatus = "new" | "planned" | "done" | "wontfix";
export interface Feedback {
  id: string;
  church_id: string | null;
  user_id: string | null;
  kind: FeedbackKind;
  message: string;
  screen: string | null;
  app_version: string | null;
  platform: string | null;
  status: FeedbackStatus;
  created_at: string;
  churches?: { name: string } | null;
}

export const DOCUMENT_TYPES = [
  "registration_receipt",
  "founding_minutes",
  "church_type",
  "leader_diploma",
  "leader_id",
] as const;
export type DocumentType = (typeof DOCUMENT_TYPES)[number];

export interface ChurchDocument {
  id: string;
  church_id: string;
  type: DocumentType;
  storage_path: string;
  file_name: string;
  status: "submitted" | "accepted" | "rejected";
  review_note: string | null;
  created_at: string;
}

export interface ReviewQueueItem {
  id: string;
  name: string;
  slug: string;
  city: string | null;
  country: string | null;
  church_type: string | null;
  submitted_for_review_at: string;
  documents: number;
  owner_name: string | null;
  owner_email: string | null;
}
