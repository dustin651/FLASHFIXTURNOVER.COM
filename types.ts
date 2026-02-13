
import type { Session } from '@supabase/supabase-js';

export interface Job {
  id: number;
  unit: string;
  client_name: string;
  client_email: string;
  address: string;
  service_type: string;
  service_date: string;
  lockbox: string;
  status: 'Pending' | 'Completed' | 'In Progress';
  checklist_notes?: string;
  created_at?: string;
  contractor_id?: number | null;
  contractor_name?: string | null;
}

export interface Contractor {
  id: number;
  name: string;
  specialty: string;
  rating: number;
  avatar: string;
}

export type UserRole = 'pm' | 'contractor' | 'admin';

export type TabId = 'dashboard' | 'booking' | 'ai' | 'history' | 'contractors' | 'my-jobs' | 'admin-panel';

export interface NavItem {
    id: TabId;
    label: string;
    icon: React.ElementType;
}

export interface AnalysisResult {
    score: number;
    status: 'PASS' | 'FAIL' | 'Error';
    issues: string[];
    summary: string;
}

export interface ManagedUser {
    id: string;
    email: string;
    role: UserRole;
    created_at: string;
}


export type { Session };
